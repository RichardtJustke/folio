cmake_minimum_required(VERSION 3.21)
project(folio VERSION 0.11.0 LANGUAGES CXX)
set(FOLIO_VERSION_STRING "0.11")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Concurrent Svg DBus)
qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

qt_add_executable(folio
    src/main.cpp
    src/IconProvider.h src/IconProvider.cpp
    src/Thumbnailer.h src/Thumbnailer.cpp
    src/FileManager1.h src/FileManager1.cpp
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

file(GLOB FOLIO_ICONS CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/assets/icons/*.svg)
list(TRANSFORM FOLIO_ICONS REPLACE "^${CMAKE_CURRENT_SOURCE_DIR}/" "")

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
        qml/components/Ghost.qml
        qml/components/FxLayer.qml
    RESOURCES
        assets/folder.svg
        assets/folio.svg
        ${FOLIO_ICONS}
)

target_include_directories(folio PRIVATE src)
target_compile_definitions(folio PRIVATE FOLIO_VERSION="${FOLIO_VERSION_STRING}")

target_link_libraries(folio PRIVATE
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Concurrent Qt6::Svg Qt6::DBus
)

include(GNUInstallDirs)
install(TARGETS folio RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES dist/folio.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
# Fora de /usr o ~/.local/bin não está no PATH de launchers (quickshell, rofi, portais...):
# o .desktop instalado leva o caminho absoluto, senão o app aparece na lista mas não abre.
install(CODE "
    set(_prefix \"\${CMAKE_INSTALL_PREFIX}\")
    if(NOT _prefix MATCHES \"^/usr(/|\$)\")
        set(_desktop \"\$ENV{DESTDIR}\${_prefix}/${CMAKE_INSTALL_DATADIR}/applications/folio.desktop\")
        file(READ \"\${_desktop}\" _content)
        string(REPLACE \"Exec=folio \" \"Exec=\${_prefix}/${CMAKE_INSTALL_BINDIR}/folio \" _content \"\${_content}\")
        file(WRITE \"\${_desktop}\" \"\${_content}\")
        # \"Mostrar na pasta\" dos outros apps (D-Bus FileManager1) abre o Folio. Só fora de /usr:
        # lá o arquivo do nautilus/dolphin tem o mesmo nome, e o de ~/.local tem precedência.
        set(_service \"\$ENV{DESTDIR}\${_prefix}/${CMAKE_INSTALL_DATADIR}/dbus-1/services/org.freedesktop.FileManager1.service\")
        message(STATUS \"Installing: \${_service}\")
        file(WRITE \"\${_service}\" \"[D-BUS Service]\\nName=org.freedesktop.FileManager1\\nExec=\${_prefix}/${CMAKE_INSTALL_BINDIR}/folio --dbus-service\\n\")
    endif()
")
install(FILES assets/folio.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
