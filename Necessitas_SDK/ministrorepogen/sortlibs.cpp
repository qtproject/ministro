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

#include "sortlibs.h"
#include <QProcess>
#include <QDirIterator>
#include <QDebug>


static QStringList getLibs(const QString &  readelfPath, const QString & lib)
{
    QStringList libs;

    QProcess readelfProc;
    readelfProc.start(readelfPath, QStringList()<<"-d"<<"-W"<<lib);

    if (!readelfProc.waitForFinished(-1))
    {
        readelfProc.terminate();
        return libs;
    }

    QList<QByteArray> lines=readelfProc.readAll().trimmed().split('\n');
    foreach(QByteArray line, lines)
    {
        if (line.contains("(NEEDED)") && line.contains("Shared library:") )
        {
            const int pos=line.lastIndexOf('[')+1;
            libs<<line.mid(pos,line.lastIndexOf(']')-pos);
        }
    }
    return libs;
}

static int setLevel(const QString & library, librariesMap & mapLibs)
{
    int maxlevel=mapLibs[library].level;
    if (maxlevel>0)
        return maxlevel;
    foreach (QString lib, mapLibs[library].dependencies)
    {
        foreach (const QString & key, mapLibs.keys())
        {
            if (library == key)
                continue;
            if (key==lib)
            {
                int libLevel=mapLibs[key].level;

                if (libLevel<0)
                    libLevel=setLevel(key, mapLibs);

                if (libLevel>maxlevel)
                    maxlevel=libLevel;
                break;
            }
        }
    }
    if (mapLibs[library].level<0)
        mapLibs[library].level=maxlevel+1;
    return maxlevel+1;
}

void SortLibraries(librariesMap & mapLibs, const QString & readelfPath, const QString & path, const QStringList & excludePath)
{
    QDir libPath;
    QDir relative;
    relative.cd(path);
    QDirIterator it(path, QStringList()<<"*.so", QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext())
    {
        libPath=it.next();
        const QString library=libPath.absolutePath().mid(libPath.absolutePath().lastIndexOf('/')+1);
        const QString relativePath=relative.relativeFilePath(libPath.absolutePath());
        if (excludePath.contains(relativePath.left(relativePath.indexOf('/'))) && !mapLibs.contains(library))
            continue;

        if (!mapLibs[library].relativePath.length())
            mapLibs[library].relativePath=relativePath;

            QStringList depends=getLibs(readelfPath, libPath.absolutePath());
            foreach(const QString & libName, depends)
            {
                if (!mapLibs[library].dependencies.contains(libName))
                        mapLibs[library].dependencies<<libName;
            }
    }

    // clean dependencies
    foreach (const QString & key, mapLibs.keys())
    {
        int it=0;
        while(it<mapLibs[key].dependencies.size())
        {
            const QString & dependName=mapLibs[key].dependencies[it];
            if (!mapLibs.keys().contains(dependName) && dependName.startsWith("lib") && dependName.endsWith(".so"))
            {
                mapLibs[key].dependencies.removeAt(it);
            }
            else
                ++it;
        }
        if (!mapLibs[key].dependencies.size())
            mapLibs[key].level = 0;
    }

    // calculate the level for every library
    foreach (const QString & key, mapLibs.keys())
    {
        if (mapLibs[key].level<0)
           setLevel(key, mapLibs);

        if (!mapLibs[key].name.length() && key.startsWith("lib") && key.endsWith(".so"))
            mapLibs[key].name=key.mid(3,key.length()-6);

        for (int it=0;it<mapLibs[key].dependencies.size();it++)
        {
            const QString & libName=mapLibs[key].dependencies[it];
            if (libName.startsWith("lib") && libName.endsWith(".so"))
                mapLibs[key].dependencies[it]=libName.mid(3,libName.length()-6);
        }
    }
}
