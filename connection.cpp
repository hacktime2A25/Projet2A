#include "connection.h"

Connection::Connection() {}

bool Connection::createconnect()
{
    QSqlDatabase db = QSqlDatabase::addDatabase("QODBC");
    db.setDatabaseName("Source_Projet2A"); // nom de la source ODBC
    db.setUserName("projet2a");            // ton utilisateur Oracle
    db.setPassword("hacktime");            // ton mot de passe
    return db.open();
}