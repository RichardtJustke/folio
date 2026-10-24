#include "SwipeGesture.h"

#include <QCoreApplication>
#include <QWheelEvent>

SwipeGesture::SwipeGesture(QObject *parent) : QObject(parent)
{
    QCoreApplication::instance()->installEventFilter(this);
}

SwipeGesture::~SwipeGesture()
{
    if (auto *app = QCoreApplication::instance())
        app->removeEventFilter(this);
}

bool SwipeGesture::eventFilter(QObject *watched, QEvent *event)
{
    // o mesmo evento passa pela janela e pelos itens: decide só uma vez, na janela
    if (event->type() != QEvent::Wheel || !watched->isWindowType())
        return false;
    auto *wheel = static_cast<QWheelEvent *>(event);
    const auto phase = wheel->phase();
    if (!m_enabled || phase == Qt::NoScrollPhase) // roda do mouse: nada a fazer
        return false;

    if (phase == Qt::ScrollBegin) {
        m_lock = Lock::Undecided;
        m_acc = {};
    }
    // pixelDelta segue o conteúdo; com rolagem natural (inverted) ele anda junto com os dedos
    QPointF d = wheel->pixelDelta();
    if (d.isNull())
        d = QPointF(wheel->angleDelta()) / 4.0;
    const qreal fingers = (wheel->inverted() ? d.x() : -d.x()) * (m_invert ? -1 : 1);
    m_acc += QPointF(fingers, d.y());

    if (m_lock == Lock::Undecided && m_acc.manhattanLength() > 10)
        m_lock = qAbs(m_acc.x()) > 2 * qAbs(m_acc.y()) ? Lock::Horizontal : Lock::Vertical;

    if (phase == Qt::ScrollEnd) {
        const bool was = m_lock == Lock::Horizontal;
        m_lock = Lock::Undecided;
        if (was)
            emit finished(m_acc.x());
        return was;
    }
    if (m_lock != Lock::Horizontal)
        return false;
    if (phase != Qt::ScrollMomentum)
        emit progress(m_acc.x());
    return true;
}
