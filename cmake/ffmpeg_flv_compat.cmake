# Rebuild only the shipped libavformat from the exact prebuilt release. Do not
# replace libavcodec/libavutil or vendor hardware decoders with a newer ABI.
foreach(component avformat avcodec avutil)
    file(STRINGS "${FFMPEG_HEADERS}/lib${component}/version.h" version_lines
        REGEX "^#define LIB[A-Z]+_VERSION_(MAJOR|MINOR|MICRO) +[0-9]+")
    set(actual "")
    foreach(line IN LISTS version_lines)
        string(REGEX REPLACE ".* +([0-9]+)$" "\\1" number "${line}")
        list(APPEND actual "${number}")
    endforeach()
    if(component STREQUAL "avformat")
        set(expected "58;76;100")
    elseif(component STREQUAL "avcodec")
        set(expected "58;134;100")
    else()
        set(expected "56;70;100")
    endif()
    if(NOT "${actual}" STREQUAL "${expected}")
        message(FATAL_ERROR "FFmpeg FLV backport needs the 4.4.6 prebuilt ABI: ${component}=${actual}")
    endif()
endforeach()

set(COSMO_FFMPEG_SOURCE_ARCHIVE "" CACHE FILEPATH "Offline copy of official ffmpeg-4.4.6.tar.xz (SHA256 checked)")
set(ffmpeg_url "https://ffmpeg.org/releases/ffmpeg-4.4.6.tar.xz")
if(COSMO_FFMPEG_SOURCE_ARCHIVE)
    set(ffmpeg_url "${COSMO_FFMPEG_SOURCE_ARCHIVE}")
endif()
set(ffmpeg_compat_prefix "${THIRDPARTY_INSTALL_PREFIX}/ffmpeg_flv_compat")
set(ffmpeg_arch_args --arch=${COSMO_TARGET_ARCH})
if(COSMO_TARGET_ARCH STREQUAL "aarch64")
    list(APPEND ffmpeg_arch_args --enable-cross-compile --cross-prefix=aarch64-linux-gnu-)
else()
    list(APPEND ffmpeg_arch_args --disable-x86asm)
endif()
find_program(COSMO_FFMPEG_MAKE NAMES gmake make REQUIRED)
ExternalProject_Add(ffmpeg_flv_compat
    URL "${ffmpeg_url}"
    URL_HASH SHA256=2290461f467c08ab801731ed412d8e724a5511d6c33173654bd9c1d2e25d0617
    PATCH_COMMAND ${CMAKE_COMMAND} "-DFFMPEG_SOURCE_DIR=<SOURCE_DIR>"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/patch_ffmpeg_flv_hevc.cmake"
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${ffmpeg_compat_prefix}
        --disable-static --enable-shared --enable-pic --enable-small
        --disable-stripping --disable-runtime-cpudetect --disable-programs
        --disable-doc --disable-debug --disable-large-tests --target-os=linux
        ${ffmpeg_arch_args}
    BUILD_COMMAND ${COSMO_FFMPEG_MAKE} -j4 libavformat/libavformat.so.58
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory "${ffmpeg_compat_prefix}/lib"
        COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libavformat/libavformat.so.58
            "${ffmpeg_compat_prefix}/lib/libavformat.so.58.76.100"
        COMMAND ${CMAKE_COMMAND} -E create_symlink libavformat.so.58.76.100
            "${ffmpeg_compat_prefix}/lib/libavformat.so.58"
        COMMAND ${CMAKE_COMMAND} -E create_symlink libavformat.so.58
            "${ffmpeg_compat_prefix}/lib/libavformat.so"
    BUILD_BYPRODUCTS "${ffmpeg_compat_prefix}/lib/libavformat.so"
    LOG_CONFIGURE ON LOG_BUILD ON LOG_INSTALL ON LOG_OUTPUT_ON_FAILURE ON
)
add_dependencies(third_build ffmpeg_flv_compat)
set(FFMPEG_AVFORMAT_LIB "${ffmpeg_compat_prefix}/lib/libavformat.so")
install(DIRECTORY "${ffmpeg_compat_prefix}/lib/" DESTINATION lib FILES_MATCHING PATTERN "*.so*")
# Ship the exact patch alongside the existing LGPL notices for reproducibility.
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/cmake/patch_ffmpeg_flv_hevc.cmake"
    DESTINATION licenses/ffmpeg)
