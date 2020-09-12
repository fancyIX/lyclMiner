/*
 * Copyright 2018-2019 CryptoGraphics <CrGr@protonmail.com>.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version. See LICENSE for more details.
 */

#ifndef AppLyra2Z_INCLUDE_ONCE
#define AppLyra2Z_INCLUDE_ONCE

#include <vector>
#include <string>
#include <cstring> // memset
#include <chrono>

#include <lyclCore/CLUtils.hpp>
#include <lyclApplets/AppCommon.hpp>

namespace lycl
{
    //-----------------------------------------------------------------------------
    // AppLyra2Z class declaration.
    //-----------------------------------------------------------------------------
    class AppLyra2Z
    {
    public:
        inline AppLyra2Z();

        //! initalization is required before using all other functions.
        inline bool onInit(const device& in_device);
        //! compute (work_size) hashes, starting from the (first_nonce) and checks hTarg.
        //! NOTE: hash results are not saved from the latest pass. Only hTarg result.
        inline void onRun(uint32_t first_nonce, size_t work_size);
        //! destroy context and free resources.
        inline void onDestroy();
        //! must be called at least once, before (onRun())
        inline void setKernelData(const KernelData& kernel_data);
        //! returns all hashes. Very slow. Used for validation
        inline void getHashes(std::vector<uint32x8>& lyra_hashes);
        //! get result based on Htarg test.
        inline void getHtArgTestResultAndSize(uint32_t& out_nonce, uint32_t& out_dbgCount);
        //! get Htarg test result buffer content
        inline void getHtArgTestResults(std::vector<uint32_t>& out_htargs, size_t num_elements, size_t offset_elem);
        //! returns hash at specific index, useful for host side validation.
        inline void getLatestHashResultForIndex(uint32_t index, uint32x8& out_hash);
        //! clear hTarg result buffer.
        inline void clearResult(size_t num_elements);

    private:
        size_t m_maxWorkSize;
        cl_context m_clContext;
        cl_command_queue m_clCommandQueue;
        // blake32
        cl_program m_clProgramBlake32;
        cl_kernel m_clKernelBlake32;
        // lyra888p1
        cl_program m_clProgramLyra888p1;
        cl_kernel m_clKernelLyra888p1;
        // lyra888p2
        cl_program m_clProgramLyra888p2;
        cl_kernel m_clKernelLyra888p2;
        // lyra888p3
        cl_program m_clProgramLyra888p3;
        cl_kernel m_clKernelLyra888p3;
        // buffers
        cl_mem m_clMemHashStorage;
        cl_mem m_clMemLyraStates;
        cl_mem m_clMemHtArgResult;

        bool usingPrebuiltBinary = false;
    };
    //-----------------------------------------------------------------------------
    // AppLyra2Z class inline methods implementation.
    //-----------------------------------------------------------------------------
    inline AppLyra2Z::AppLyra2Z() { }
    //-----------------------------------------------------------------------------
    inline bool AppLyra2Z::onInit(const device& in_device)
    {
        std::string deviceName;
        m_maxWorkSize = in_device.workSize; 
        cl_int errorCode = CL_SUCCESS;

        //-------------------------------------
        // Get device name for debug log.
        size_t infoSize;
        clGetDeviceInfo(in_device.clId, CL_DEVICE_NAME, 0, NULL, &infoSize);
        //clDevice.name.resize(infoSize - 1);
        deviceName.resize(infoSize);
        clGetDeviceInfo(in_device.clId, CL_DEVICE_NAME, infoSize, (void *)deviceName.data(), NULL);
        deviceName.pop_back();

        //-------------------------------------
        // Create an OpenCL context
        cl_context_properties contextProperties[] =
        {
            CL_CONTEXT_PLATFORM,
            (cl_context_properties)in_device.clPlatformId,
            0
        };
        // create 1 context for each device
        m_clContext = clCreateContext(contextProperties, 1, &in_device.clId, nullptr, nullptr, &errorCode);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create an OpenCL context. Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }

        //-------------------------------------
        // Create an OpenCL command queue
#ifndef CL_API_SUFFIX__VERSION_2_0
        //clCreateCommandQueue() // deprecated in 2.0
        m_clCommandQueue = clCreateCommandQueue(m_clContext, in_device.clId, 0, &errorCode);  
#else  
        m_clCommandQueue = clCreateCommandQueueWithProperties(m_clContext, in_device.clId, nullptr, &errorCode);
#endif
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create a command queue. Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        
        //-------------------------------------
        // Create buffers
        m_clMemHashStorage = clCreateBuffer(m_clContext, CL_MEM_READ_WRITE, sizeof(uint32x8)*m_maxWorkSize, nullptr, &errorCode);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create a hash storage buffer. Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        m_clMemLyraStates = clCreateBuffer(m_clContext, CL_MEM_READ_WRITE, sizeof(uint32x8)*m_maxWorkSize*4, nullptr, &errorCode);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create a lyra state buffer. Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        m_clMemHtArgResult = clCreateBuffer(m_clContext, CL_MEM_READ_WRITE, sizeof(uint32_t) * (m_maxWorkSize + 1), nullptr, &errorCode); // Too much, but 100% robust.
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create an HTarg result buffer. Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        // Result counter must be initialized to 0.
        clearResult(1);

        //-------------------------------------
        // Create an OpenCL blake32 kernel
        m_clProgramBlake32 = cluCreateProgramFromFile(m_clContext, in_device.clId, "kernels/blake32/blake32.cl");
        if (m_clProgramBlake32 == NULL)
        {
            std::cerr << "Failed to create CL program from source(blake32). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }

        m_clKernelBlake32 = clCreateKernel(m_clProgramBlake32, "blake32", &errorCode);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create kernel(blake32). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        errorCode = clSetKernelArg(m_clKernelBlake32, 0, sizeof(cl_mem), &m_clMemHashStorage);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Error setting kernel argument(0) inside kernel(blake32). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }

        //-------------------------------------
        // Create an OpenCL lyra888p1 kernel
        m_clProgramLyra888p1 = cluCreateProgramFromFile(m_clContext, in_device.clId, "kernels/lyra888p1/lyra888p1.cl");
        if (m_clProgramLyra888p1 == NULL)
        {
            std::cerr << "Failed to create CL program from source(lyra888p1). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }

        m_clKernelLyra888p1 = clCreateKernel(m_clProgramLyra888p1, "lyra888p1", &errorCode);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create kernel(lyra888p1). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        errorCode = clSetKernelArg(m_clKernelLyra888p1, 0, sizeof(cl_mem), &m_clMemHashStorage);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Error setting kernel argument(0) inside kernel(lyra888p1). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        errorCode = clSetKernelArg(m_clKernelLyra888p1, 1, sizeof(cl_mem), &m_clMemLyraStates);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Error setting kernel argument(1) inside kernel(lyra888p1). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }

        //-------------------------------------
        // Create an OpenCL lyra888p2 kernel

        bool asmSuccess = false;

        // try to load an asm program first.
        if (in_device.asmProgram == AP_GFX6)
        {
            std::string asmProgramFileName;

            if (in_device.binaryFormat == BF_AMDCL2)
                asmProgramFileName = "kernels/lyra888p2/lyra888p2_gfx6_amdcl2.bin";

            m_clProgramLyra888p2 = cluCreateProgramWithBinaryFromFile(m_clContext, in_device.clId, asmProgramFileName);
            if (m_clProgramLyra888p2 == NULL)
                std::cerr << "Failed to create ASM program(lyra888p2). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            else
                asmSuccess = true;
        }
        else if (in_device.asmProgram == AP_GFX7)
        {
            std::string asmProgramFileName;

            if (in_device.binaryFormat == BF_AMDCL2)
                asmProgramFileName = "kernels/lyra888p2/lyra888p2_gfx7_amdcl2.bin";

            m_clProgramLyra888p2 = cluCreateProgramWithBinaryFromFile(m_clContext, in_device.clId, asmProgramFileName);
            if (m_clProgramLyra888p2 == NULL)
                std::cerr << "Failed to create ASM program(lyra888p2). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            else
                asmSuccess = true;
        }
        else if (in_device.asmProgram == AP_GFX8)
        {
            std::string asmProgramFileName;
            if (in_device.binaryFormat == BF_AMDCL2)
                asmProgramFileName = "kernels/lyra888p2/lyra888p2_gfx8_amdcl2.bin";
            else if (in_device.binaryFormat == BF_ROCm)
                asmProgramFileName = "kernels/lyra888p2/lyra888p2_gfx8_rocm.bin";

            m_clProgramLyra888p2 = cluCreateProgramWithBinaryFromFile(m_clContext, in_device.clId, asmProgramFileName);
            if (m_clProgramLyra888p2 == NULL)
                std::cerr << "Failed to create ASM program(lyra888p2). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            else
                asmSuccess = true;
        }
        else if (in_device.asmProgram == AP_GFX9)
        {
            std::string asmProgramFileName;

            if (in_device.binaryFormat == BF_AMDCL2)
                asmProgramFileName = "kernels/lyra888p2/lyra888p2_gfx9_amdcl2.bin";
            if (in_device.binaryFormat == BF_ROCm)
                asmProgramFileName = "kernels/lyra888p2/lyra888p2_gfx9_rocm.bin";

            m_clProgramLyra888p2 = cluCreateProgramWithBinaryFromFile(m_clContext, in_device.clId, asmProgramFileName);
            if (m_clProgramLyra888p2 == NULL)
                std::cerr << "Failed to create ASM program(lyra888p2). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            else
                asmSuccess = true;
        }
        else if (in_device.asmProgram == AP_GFX906)
        {
            std::string asmProgramFileName;

            if (in_device.binaryFormat == BF_AMDCL2)
                std::cerr << "gfx906 kernel is not available for AMDCL2 platform" << std::endl;
            if (in_device.binaryFormat == BF_ROCm)
                asmProgramFileName = "kernels/lyra888p2/lyra888p2_gfx906_rocm.bin";

            m_clProgramLyra888p2 = cluCreateProgramWithBinaryFromFile(m_clContext, in_device.clId, asmProgramFileName);
            if (m_clProgramLyra888p2 == NULL)
                std::cerr << "Failed to create ASM program(lyra888p2). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            else
                asmSuccess = true;
        }
        else
        {
            std::cout << "Debug: Asm kernel is not available or disabled. Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
        }

        if (!asmSuccess)
        {
            // Fallback to the OpenCL kernel.
            m_clProgramLyra888p2 = cluCreateProgramFromFile(m_clContext, in_device.clId, "kernels/lyra888p2/lyra888p2.cl");
            if (m_clProgramLyra888p2 == NULL)
            {
                std::cerr << "Failed to create CL program from source(lyra888p2). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
                return false;
            }
        }
        usingPrebuiltBinary = asmSuccess;

        m_clKernelLyra888p2 = clCreateKernel(m_clProgramLyra888p2, "search2", &errorCode);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create kernel(lyra888p2). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        errorCode = clSetKernelArg(m_clKernelLyra888p2, 0, sizeof(cl_mem), &m_clMemLyraStates);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Error setting kernel argument(0) inside kernel(lyra888p2). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }

        //-------------------------------------
        // Create an OpenCL lyra888p3 kernel
        m_clProgramLyra888p3 = cluCreateProgramFromFile(m_clContext, in_device.clId, "kernels/lyra888p3/lyra888p3.cl");
        if (m_clProgramLyra888p3 == NULL)
        {
            std::cerr << "Failed to create a CL program from source(lyra888p3). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        m_clKernelLyra888p3 = clCreateKernel(m_clProgramLyra888p3, "lyra888p3", &errorCode);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to create a kernel(lyra888p3). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        errorCode = clSetKernelArg(m_clKernelLyra888p3, 0, sizeof(cl_mem), &m_clMemHashStorage);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Error setting kernel argument(0) inside kernel(lyra888p3). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        errorCode = clSetKernelArg(m_clKernelLyra888p3, 1, sizeof(cl_mem), &m_clMemLyraStates);
        if (errorCode != CL_SUCCESS)
        {
            std::cerr << "Error setting kernel argument(1) inside kernel(lyra888p3). Device(" << deviceName << ") Platform index(" << in_device.platformIndex << ")" << std::endl;
            return false;
        }
        
        return true;
    }
    //-----------------------------------------------------------------------------
    inline void AppLyra2Z::onRun(uint32_t first_nonce, size_t num_hashes)
    {
        if (num_hashes > m_maxWorkSize)
        {
            std::cout << "Warning: numHashes > maxHashesPerRun!" << std::endl;
            num_hashes = m_maxWorkSize;
        }

        clSetKernelArg(m_clKernelBlake32, 12, sizeof(uint32_t), &first_nonce);

        const size_t globalWorkSize1x = num_hashes;
        const size_t globalWorkSize4x = num_hashes*4;
        const size_t localWorkSize256 = 256;
        const size_t localWorkSize64  = 64;

        // blake32
        clEnqueueNDRangeKernel(m_clCommandQueue, m_clKernelBlake32, 1, nullptr,
                               &globalWorkSize1x, &localWorkSize256, 0, nullptr, nullptr);
        // lyra888p1
        clEnqueueNDRangeKernel(m_clCommandQueue, m_clKernelLyra888p1, 1, nullptr,
                               &globalWorkSize1x, &localWorkSize256, 0, nullptr, nullptr);
        // lyra888p2
        if (usingPrebuiltBinary) {
            const size_t off[] = { 0, 0, 0 };
	        const size_t gws[] = { 4, 4, globalWorkSize1x / 2 };
	        const size_t expand[] = { 4, 4, 16 };
            clEnqueueNDRangeKernel(m_clCommandQueue, m_clKernelLyra888p2, 3, off,
                               gws, expand, 0, nullptr, nullptr);
        } else {
            const size_t off[] = { 0, 0 };
	        const size_t gws[] = { 4, globalWorkSize1x };
	        const size_t expand[] = { 4, 5 };
            clEnqueueNDRangeKernel(m_clCommandQueue, m_clKernelLyra888p2, 2, off,
                               gws, expand, 0, nullptr, nullptr);
        }
        // lyra888p3
        clEnqueueNDRangeKernel(m_clCommandQueue, m_clKernelLyra888p3, 1, nullptr,
                               &globalWorkSize1x, &localWorkSize256, 0, nullptr, nullptr);
       
        clFinish(m_clCommandQueue);
    }
    //-----------------------------------------------------------------------------
    inline void AppLyra2Z::getHashes(std::vector<uint32x8>& lyra_hashes)
    {
        if(lyra_hashes.size() < m_maxWorkSize)
            lyra_hashes.resize(m_maxWorkSize);    
        clEnqueueReadBuffer(m_clCommandQueue, m_clMemHashStorage, CL_TRUE, 0, m_maxWorkSize * sizeof(uint32x8), lyra_hashes.data(), 0, nullptr, nullptr);
    }
    //-----------------------------------------------------------------------------
    //inline void AppLyra2Z::clearResult()
    inline void AppLyra2Z::clearResult(size_t num_elements)
    {
        // prepare clear buffer
        // opencl 1.2+
        cl_uint zero = 0;
        //int errorCode = clEnqueueFillBuffer(m_clCommandQueue, m_clMemHtArgResult, &zero, sizeof(uint32_t), 0, sizeof(uint32_t)*2, 0, nullptr, nullptr);
        // clear numElements+Elements...
        int errorCode = clEnqueueFillBuffer(m_clCommandQueue, m_clMemHtArgResult, &zero, sizeof(uint32_t), 0, (sizeof(uint32_t)*num_elements) + 1, 0, nullptr, nullptr);
        if(errorCode != CL_SUCCESS)
        {
            std::cerr << "Failed to clear a hTarg buffer object!" << std::endl;
        }

        // slower alternative
        //uint32_t bdata[2] = { 0 };
        //clEnqueueWriteBuffer(m_clCommandQueue, m_clMemHtArgResult, CL_TRUE, 0, sizeof(uint32_t)*2, &bdata[0], 0, nullptr, nullptr);
    }
    //-----------------------------------------------------------------------------
    inline void AppLyra2Z::setKernelData(const KernelData& kernel_data)
    {
        clSetKernelArg(m_clKernelBlake32, 1, sizeof(uint32_t), &kernel_data.uH0);
        clSetKernelArg(m_clKernelBlake32, 2, sizeof(uint32_t), &kernel_data.uH1);
        clSetKernelArg(m_clKernelBlake32, 3, sizeof(uint32_t), &kernel_data.uH2);
        clSetKernelArg(m_clKernelBlake32, 4, sizeof(uint32_t), &kernel_data.uH3);
        clSetKernelArg(m_clKernelBlake32, 5, sizeof(uint32_t), &kernel_data.uH4);
        clSetKernelArg(m_clKernelBlake32, 6, sizeof(uint32_t), &kernel_data.uH5);
        clSetKernelArg(m_clKernelBlake32, 7, sizeof(uint32_t), &kernel_data.uH6);
        clSetKernelArg(m_clKernelBlake32, 8, sizeof(uint32_t), &kernel_data.uH7);
        clSetKernelArg(m_clKernelBlake32, 9, sizeof(uint32_t), &kernel_data.in16);
        clSetKernelArg(m_clKernelBlake32, 10, sizeof(uint32_t), &kernel_data.in17);
        clSetKernelArg(m_clKernelBlake32, 11, sizeof(uint32_t), &kernel_data.in18);
    }
    //-----------------------------------------------------------------------------
    inline void AppLyra2Z::getHtArgTestResultAndSize(uint32_t &out_nonce, uint32_t &out_dbgCount)
    {
        uint32_t aResult[2];
        // assume only one nonce was found here
        clEnqueueReadBuffer(m_clCommandQueue, m_clMemHtArgResult, CL_TRUE, 0, 2 * sizeof(uint32_t), &aResult[0], 0, nullptr, nullptr);

        out_nonce = aResult[1];
        out_dbgCount = aResult[0];
    }
    //-----------------------------------------------------------------------------
    inline void AppLyra2Z::getHtArgTestResults(std::vector<uint32_t>& out_htargs, size_t num_elements, size_t offset_elem)
    {
        if(out_htargs.size() < num_elements)
            out_htargs.resize(num_elements);    
        clEnqueueReadBuffer(m_clCommandQueue, m_clMemHtArgResult, CL_TRUE, offset_elem * sizeof(uint32_t), num_elements*sizeof(uint32_t), out_htargs.data(), 0, nullptr, nullptr);
    }
    //-----------------------------------------------------------------------------
    inline void AppLyra2Z::getLatestHashResultForIndex(uint32_t index, uint32x8& out_hash)
    {
        clEnqueueReadBuffer(m_clCommandQueue, m_clMemHashStorage, CL_TRUE, (size_t)sizeof(uint32x8)*index, sizeof(uint32x8), &out_hash, 0, nullptr, nullptr);
    }
    //-----------------------------------------------------------------------------
    inline void AppLyra2Z::onDestroy()
    {
        // memory objects
        clReleaseMemObject(m_clMemHashStorage);
        clReleaseMemObject(m_clMemLyraStates);
        clReleaseMemObject(m_clMemHtArgResult);
        // lyra888p3
        clReleaseKernel(m_clKernelLyra888p3);
        clReleaseProgram(m_clProgramLyra888p3);
        // lyra888p2
        clReleaseKernel(m_clKernelLyra888p2);
        clReleaseProgram(m_clProgramLyra888p2);
        // lyra888p1
        clReleaseKernel(m_clKernelLyra888p1);
        clReleaseProgram(m_clProgramLyra888p1);
        // misc
        clReleaseCommandQueue(m_clCommandQueue);
        clReleaseContext(m_clContext);
    }
    //-----------------------------------------------------------------------------
}

#endif // !AppLyra2Z_INCLUDE_ONCE

