#pragma once

#include <QObject>
#include <QPointF>
#include <QQmlEngine>

// Deslizar dois dedos para o lado no touchpad (voltar/avançar, como nos navegadores).
// Filtra os eventos de rolagem com fase (só touchpads as mandam) de toda a aplicação:
// rolagens horizontais viram gesto e não chegam às vistas; as verticais seguem normais.
class SwipeGesture : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled MEMBER m_enabled NOTIFY enabledChanged)
    Q_PROPERTY(bool invert MEMBER m_invert NOTIFY enabledChanged)
    Q_PROPERTY(qreal threshold MEMBER m_threshold CONSTANT)

public:
    explicit SwipeGesture(QObject *parent = nullptr);
    ~SwipeGesture() override;

signals:
    void enabledChanged();
    // distância percorrida pelos dedos (px; positivo = para a direita = voltar)
    void progress(qreal distance);
    void finished(qreal distance);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    enum class Lock { Undecided, Horizontal, Vertical };
    bool m_enabled = true;
    bool m_invert = false;
    qreal m_threshold = 140;
    Lock m_lock = Lock::Undecided;
    QPointF m_acc;
};
