cmake_minimum_required(VERSION 3.21)
project(folio VERSION 0.3.0 LANGUAGES CXX)
set(FOLIO_VERSION_STRING "0.3")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Concurrent Svg)
qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

qt_add_executable(folio
    src/main.cpp
    src/IconProvider.h src/IconProvider.cpp
    src/Thumbnailer.h src/Thumbnailer.cpp
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(folio
    URI Folio
    VERSION 1.0
    SOURCES
        src/FileEntry.h
        src/FileModel.h src/FileModel.cpp
        src/RowModel.h src/RowModel.cpp
        src/Navigator.h src/Navigator.cpp
        src/FileOps.h src/FileOps.cpp
        src/PlacesModel.h src/PlacesModel.cpp
        src/Config.h src/Config.cpp
        src/Settings.h src/Settings.cpp
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/components/WindowControls.qml
        qml/components/PathBar.qml
        qml/components/SettingsPage.qml
        qml/components/PropertiesDialog.qml
        qml/components/OpenWithDialog.qml
        qml/components/PromptDialog.qml
        qml/components/ConnectDialog.qml
        qml/components/ListPickerDialog.qml
        qml/components/Sidebar.qml
        qml/components/SidebarItem.qml
        qml/components/NavPill.qml
        qml/components/HeaderBar.qml
        qml/components/FileGrid.qml
        qml/components/FileTile.qml
        qml/components/SectionHeader.qml
        qml/components/FolderIcon.qml
        qml/components/GlassMenu.qml
        qml/components/GlassMenuItem.qml
        qml/components/ResizeHandles.qml
        qml/components/Toast.qml
        qml/components/BrowserTab.qml
        qml/components/TabStrip.qml
        qml/components/FileListRow.qml
        qml/components/ListHeader.qml
        qml/components/FileInteraction.qml
        qml/components/SearchField.qml
        qml/components/QuickLook.qml
        qml/components/GlassPopup.qml
        qml/components/DialogButton.qml
        qml/components/ConfirmDialog.qml
        qml/components/ConflictDialog.qml
        qml/components/RenameField.qml
    RESOURCES
        assets/folder.svg
        assets/folio.svg
)

target_include_directories(folio PRIVATE src)
target_compile_definitions(folio PRIVATE FOLIO_VERSION="${FOLIO_VERSION_STRING}")

target_link_libraries(folio PRIVATE
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Concurrent Qt6::Svg
)

include(GNUInstallDirs)
install(TARGETS folio RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES dist/folio.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES assets/folio.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
