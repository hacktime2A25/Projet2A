#include "mainwindow.h"
#include "connection.h"
#include <QApplication>
#include <QMessageBox>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    Connection c;
    MainWindow w;

    if (c.createconnect()) {
        w.show();
        QMessageBox::information(nullptr, "Base de données",
                                 "Connexion réussie.");
    } else {
        QMessageBox::critical(nullptr, "Base de données",
                              "Échec de la connexion.");
    }
    return a.exec();
}