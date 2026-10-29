# CMakeLists.txt — libicomos_engine (GMP + libsodium: vendido OU sistema)
cmake_minimum_required(VERSION 3.16)
project(icomos_engine LANGUAGES C VERSION 0.0.1)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(MARTELOS "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/martelos")
set(VEND_TRIPLET "linux-x86_64")
set(VEND_GMP "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/gmp/${VEND_TRIPLET}")
set(VEND_SOD "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/sodium/${VEND_TRIPLET}")

# --- libsodium (criptografia de envelope) -----------------------------------
if (EXISTS "${VEND_SOD}/include/sodium.h")
  set(SOD_INCLUDE_DIRS "${VEND_SOD}/include")
  set(SOD_LIBRARIES "${VEND_SOD}/lib/libsodium.a")
  message(STATUS "libsodium vendido: ${VEND_SOD}")
else()
  find_path(SOD_H sodium.h)
  find_library(SOD_LIB sodium)
  if (NOT SOD_H OR NOT SOD_LIB)
    message(FATAL_ERROR "libsodium não encontrado: rode tools/fetch-sodium.sh ou instale libsodium-dev")
  endif()
  set(SOD_INCLUDE_DIRS ${SOD_H})
  set(SOD_LIBRARIES ${SOD_LIB})
  message(STATUS "libsodium do sistema: ${SOD_LIB}")
endif()

# --- GMP (motor MARTELOS usa mpf para as constantes) ------------------------
if (EXISTS "${VEND_GMP}/include/gmp.h")
  set(GMP_INCLUDE_DIRS "${VEND_GMP}/include")
  set(GMP_LIBRARIES "${VEND_GMP}/lib/libgmp.a")
  message(STATUS "GMP vendido: ${VEND_GMP}")
else()
  find_package(PkgConfig QUIET)
  if (PkgConfig_FOUND)
    pkg_check_modules(GMP QUIET IMPORTED_TARGET gmp)
  endif()
  if (GMP_FOUND)
    set(GMP_LIBRARIES PkgConfig::GMP)
    message(STATUS "GMP do sistema (pkg-config)")
  else()
    find_path(GMP_H gmp.h)
    find_library(GMP_LIB gmp)
    if (NOT GMP_H OR NOT GMP_LIB)
      message(FATAL_ERROR "GMP não encontrado: rode tools/fetch-gmp.sh ou instale libgmp-dev")
    endif()
    set(GMP_INCLUDE_DIRS ${GMP_H})
    set(GMP_LIBRARIES ${GMP_LIB})
    message(STATUS "GMP do sistema: ${GMP_LIB}")
  endif()
endif()

# --- Fontes: ponte + motor (Fase 2: texto + cripto + kdf) --------------------
set(MARTELOS_SRC
  ${MARTELOS}/alfabeto.c
  ${MARTELOS}/crypto.c
  ${MARTELOS}/motor.c
  ${MARTELOS}/parser.c
)

set(ENGINE_SRC
  src/bridge.c
  src/kdf.c
  src/crypto.c
)

add_library(icomos_engine SHARED ${ENGINE_SRC} ${MARTELOS_SRC})

target_include_directories(icomos_engine PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${MARTELOS}
  ${GMP_INCLUDE_DIRS}
  ${SOD_INCLUDE_DIRS}
)

# -lm: parser.c usa sin/cos; sodium é estático (autocontido no .so).
target_link_libraries(icomos_engine PRIVATE m ${SOD_LIBRARIES} ${GMP_LIBRARIES})

set_target_properties(icomos_engine PROPERTIES
  OUTPUT_NAME "icomos_engine"
  VERSION "0.0.1"
  SOVERSION "0"
)

install(TARGETS icomos_engine DESTINATION lib)
