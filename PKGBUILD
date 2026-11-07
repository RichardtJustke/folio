# makepkg -si  (rodar na raiz do projeto)
pkgname=folio
pkgver=0.36
pkgrel=1
pkgdesc="Gerenciador de arquivos estilo Finder para Wayland (Qt 6/QML)"
arch=('x86_64')
license=('MIT')
depends=('qt6-base' 'qt6-declarative' 'qt6-svg' 'xdg-utils')
optdepends=('udisks2: ejetar drives' 'ffmpegthumbnailer: miniaturas de vídeo' 'papirus-icon-theme: mais ícones'
            'rclone: Google Drive, OneDrive, Dropbox e outras nuvens' 'git: integração com Git' '7zip: arquivos .7z e .rar'
            'imagemagick: converter e redimensionar imagens' 'ffmpeg: converter vídeos e extrair áudio'
            'poppler: juntar PDFs' 'xdg-desktop-portal: Folio como seletor de "Abrir"/"Salvar como" dos apps')
makedepends=('cmake' 'ninja')

build() {
  cmake -S "$startdir" -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
  cmake --build build
}

package() {
  DESTDIR="$pkgdir" cmake --install build
}
