# makepkg -si  (rodar na raiz do projeto)
pkgname=folio
pkgver=0.9
pkgrel=1
pkgdesc="Gerenciador de arquivos estilo Finder para Wayland (Qt 6/QML)"
arch=('x86_64')
license=('MIT')
depends=('qt6-base' 'qt6-declarative' 'qt6-svg' 'xdg-utils')
optdepends=('udisks2: ejetar drives' 'ffmpegthumbnailer: miniaturas de vídeo' 'papirus-icon-theme: mais ícones')
makedepends=('cmake' 'ninja')

build() {
  cmake -S "$startdir" -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
  cmake --build build
}

package() {
  DESTDIR="$pkgdir" cmake --install build
}
