// Minimal Windows Route D feasibility probe. Own implementation using SDK APIs.
// Proves system demux/decode and timestamp access, not all five operations.
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>
#include <cstdio>
using Microsoft::WRL::ComPtr;

int wmain(int argc, wchar_t** argv) {
    if (argc != 2) return 2;
    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(hr)) return 3;
    hr = MFStartup(MF_VERSION);
    if (FAILED(hr)) { CoUninitialize(); return 4; }
    int result = 0;
    {
        ComPtr<IMFAttributes> attributes;
        ComPtr<IMFSourceReader> reader;
        ComPtr<IMFMediaType> rgb;
        hr = MFCreateAttributes(&attributes, 1);
        if (SUCCEEDED(hr)) hr = attributes->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
        if (SUCCEEDED(hr)) hr = MFCreateSourceReaderFromURL(argv[1], attributes.Get(), &reader);
        if (SUCCEEDED(hr)) hr = MFCreateMediaType(&rgb);
        if (SUCCEEDED(hr)) hr = rgb->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
        if (SUCCEEDED(hr)) hr = rgb->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
        if (SUCCEEDED(hr)) hr = reader->SetCurrentMediaType(MF_SOURCE_READER_FIRST_VIDEO_STREAM, nullptr, rgb.Get());
        unsigned samples = 0;
        LONGLONG last = 0;
        while (SUCCEEDED(hr)) {
            DWORD stream = 0, flags = 0;
            LONGLONG timestamp = 0;
            ComPtr<IMFSample> sample;
            hr = reader->ReadSample(MF_SOURCE_READER_FIRST_VIDEO_STREAM, 0, &stream, &flags, &timestamp, &sample);
            if (FAILED(hr) || (flags & MF_SOURCE_READERF_ENDOFSTREAM)) break;
            if (sample) { ++samples; last = timestamp; }
        }
        std::printf("{\"hresult\":\"0x%08lx\",\"decodedVideoFrames\":%u,\"lastTimestamp100ns\":%lld}\n", hr, samples, last);
        if (FAILED(hr) || samples != 300) result = 1;
    }
    MFShutdown(); CoUninitialize(); return result;
}
