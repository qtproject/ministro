/*
    Copyright (c) 2011, BogDan Vatra <bog_dan_ro@yahoo.com>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of
    the License or (at your option) version 3 or any later version
    accepted by the membership of KDE e.V. (or its successor approved
    by the membership of KDE e.V.), which shall act as a proxy
    defined in Section 14 of version 3 of the license.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <QtCore/QCoreApplication>
#include "sortlibs.h"
#include <QDebug>
#include <QDomDocument>
#include <QFile>
#include <QDir>
#include <QCryptographicHash>

void printHelp()
{
    qDebug()<<"Usage:./ministrorepogen <readelf executable path> <libraries path> <version> <abi version> <xml rules file> <output folder> ";
}


void getFileInfo(const QString & filePath, qint64 & fileSize, QString & sha1)
{
    fileSize = -1;
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
        return;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    hash.addData(file.readAll());
    sha1=hash.result().toHex();
    fileSize=file.size();
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    if (argc<7)
    {
        printHelp();
        return 1;
    }

    const char * readelfPath=argv[1];
    QString libsPath(argv[2]);
    const char * version=argv[3];
    const char * abiVersion=argv[4];
    const char * rulesFile=argv[5];
    const char * outputFolder=argv[6];

    QDomDocument document("libs");
    QFile f(rulesFile);
    if (!f.open(QIODevice::ReadOnly))
        return 1;
    document.setContent(&f);
    QDomElement root=document.documentElement();
    if (root.isNull())
        return 1;

    QDomElement element=root.firstChildElement("platforms");
    if (element.isNull())
        return 1;

    QMap<int, QVector<int> >platforms;
    element=element.firstChildElement("version");
    while(!element.isNull())
    {
        if (element.hasAttribute("symlink"))
            platforms[element.attribute("symlink", 0).toInt()].push_back(element.attribute("value", 0).toInt());
        else
            platforms[element.attribute("value", 0).toInt()].clear();
        element = element.nextSiblingElement();
    }

    element=root.firstChildElement("libs");
        if (element.isNull())
            return 1;

    QStringList excludePaths=element.attribute("excludePaths").split(';');
    QString applicationParameters=element.attribute("applicationParameters");
    QString environmentVariables=element.attribute("environmentVariables");

    element=element.firstChildElement("lib");
    librariesMap libs;
    while(!element.isNull())
    {
        if (!element.hasAttribute("file"))
        {
            element=element.nextSiblingElement();
            continue;
        }

        const QString filePath=element.attribute("file");
        const QString libraryName=filePath.mid(filePath.lastIndexOf('/')+1);
        libs[libraryName].relativePath=filePath;

        if (element.hasAttribute("name"))
            libs[libraryName].name=element.attribute("name");

        if (element.hasAttribute("platform"))
            libs[libraryName].platform=element.attribute("platform").toInt();

        if (element.hasAttribute("level"))
        {
            bool ok=false;
            libs[libraryName].level=element.attribute("level").toInt(&ok);
            if (!ok)
                libs[libraryName].level=-1;
        }

        QDomElement childs=element.firstChildElement("depends").firstChildElement("lib");
        while(!childs.isNull())
        {
            libs[libraryName].dependencies<<childs.attribute("name");
            childs=childs.nextSiblingElement();
        }

        childs=element.firstChildElement("needs").firstChildElement("item");
        while(!childs.isNull())
        {
            NeedsStruct needed;
            needed.name=childs.attribute("name");
            needed.relativePath=childs.attribute("file");
            libs[libraryName].needs<<needed;
            childs=childs.nextSiblingElement();
        }
        element=element.nextSiblingElement();
    }
    SortLibraries(libs, readelfPath, libsPath, excludePaths);

    QDir path;
    QString xmlPath(outputFolder+QString("/android/%1/").arg(abiVersion));
    path.mkpath(xmlPath);
    path.cd(xmlPath);
    chdir(path.absolutePath().toUtf8().constData());
    foreach (int androdPlatform, platforms.keys())
    {
        qDebug()<<"============================================";
        qDebug()<<"Generating repository for android platform :"<<androdPlatform;
        qDebug()<<"--------------------------------------------";
        path.mkpath(QString("android-%1").arg(androdPlatform));
        xmlPath=QString("android-%1/libs-%2.xml").arg(androdPlatform).arg(version);
        foreach(int symLink, platforms[androdPlatform])
            QFile::link(QString("android-%1").arg(androdPlatform), QString("android-%1").arg(symLink));
        QFile outXmlFile(xmlPath);
        outXmlFile.open(QIODevice::WriteOnly);
        outXmlFile.write(QString("<libs version=\"%1\" applicationParameters=\"%2\" environmentVariables=\"%3\">\n").arg(version).arg(applicationParameters).arg(environmentVariables).toUtf8());
        foreach (const QString & key, libs.keys())
        {
            if (libs[key].platform && libs[key].platform != androdPlatform)
                continue;
            qDebug()<<"Generating "<<key<<" informations";
            qint64 fileSize;
            QString sha1Hash;
            getFileInfo(libsPath+"/"+libs[key].relativePath, fileSize, sha1Hash);
            if (-1==fileSize)
            {
                qWarning()<<"Warning : Can't find \""<<libsPath+"/"+libs[key].relativePath<<"\" item will be skipped";
                continue;
            }
            outXmlFile.write(QString("\t<lib name=\"%1\" url=\"http://files.kde.org/necessitas/qt/android/%2/objects/%3/%4\" file=\"%4\" size=\"%5\" sha1=\"%6\" level=\"%7\"")
                             .arg(libs[key].name).arg(abiVersion).arg(version).arg(libs[key].relativePath).arg(fileSize).arg(sha1Hash).arg(libs[key].level).toUtf8());
            if (!libs[key].dependencies.size() && !libs[key].needs.size())
            {
                outXmlFile.write(" />\n\n");
                continue;
            }
            outXmlFile.write(">\n");
            if (libs[key].dependencies.size())
            {
                outXmlFile.write("\t\t<depends>\n");
                foreach(const QString & libName, libs[key].dependencies)
                    outXmlFile.write(QString("\t\t\t<lib name=\"%1\"/>\n").arg(libName).toUtf8());
                outXmlFile.write("\t\t</depends>\n");
            }


            if (libs[key].needs.size())
            {
                outXmlFile.write("\t\t<needs>\n");
                foreach(const NeedsStruct & needed, libs[key].needs)
                {
                    qint64 fileSize;
                    QString sha1Hash;
                    getFileInfo(libsPath+"/"+needed.relativePath, fileSize, sha1Hash);
                    if (-1==fileSize)
                    {
                        qWarning()<<"Warning : Can't find \""<<libsPath+"/"+needed.relativePath<<"\" item will be skipped";
                        continue;
                    }
                    outXmlFile.write(QString("\t\t\t<item name=\"%1\" url=\"http://files.kde.org/necessitas/qt/android/%2/objects/%3/%4\" file=\"%4\" size=\"%5\" sha1=\"%6\" />\n")
                                     .arg(needed.name).arg(abiVersion).arg(version).arg(needed.relativePath).arg(fileSize).arg(sha1Hash).toUtf8());
                }
                outXmlFile.write("\t\t</needs>\n");
            }
            outXmlFile.write("\t</lib>\n\n");
        }
        outXmlFile.write("</libs>\n");
        outXmlFile.close();
    }
    return 0;
}
