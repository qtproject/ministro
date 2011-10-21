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

#ifndef SORTLIBS_H
#define SORTLIBS_H

#include <QMap>
#include <QVector>
#include <QStringList>


struct NeedsStruct
{
    QString name;
    QString relativePath;
    QString type;
};

struct Library
{
    Library()
    {
        level = -1;
        platform = 0;
    }
    int level;
    QString relativePath;
    QStringList dependencies;
    QStringList replaces;
    QVector<NeedsStruct> needs;
    QString name;
    int platform;
};

typedef QMap<QString, Library>  librariesMap;

void SortLibraries(librariesMap & libraries, const QString & readelfPath, const QString & path, const QStringList & excludePath);

#endif // SORTLIBS_H
