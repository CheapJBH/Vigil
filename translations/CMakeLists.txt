include(CreateTranslations)
include(ImportQtTranslations)

file(GLOB vigil_translations ${CMAKE_CURRENT_SOURCE_DIR}/*.ts)
file(GLOB_RECURSE vigil_sources ${CMAKE_SOURCE_DIR}/*.cpp ${CMAKE_SOURCE_DIR}/*.h ${CMAKE_SOURCE_DIR}/*.ui ${CMAKE_SOURCE_DIR}/*.qml)
string(REGEX REPLACE "${CMAKE_SOURCE_DIR}/3rdparty[^;]+;?" "" vigil_sources "${vigil_sources}")
string(REGEX REPLACE "${CMAKE_SOURCE_DIR}/addons[^;]+;?" "" vigil_sources "${vigil_sources}")

create_translations(vigil "${vigil_translations}" "${vigil_sources}")
import_qt_translations()
