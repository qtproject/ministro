/*
    Copyright (c) 2011, BogDan Vatra <bog_dan_ro@yahoo.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

package eu.licentia.necessitas.ministro;

import java.util.ArrayList;

import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;


class Library
{
	public String name = null;
	public String filePath = null;
	public String[] depends = null; 
	public String[] replaces = null;
	public NeedsStruct[] needs = null;
	public int level=0;
	public long size = 0;
	public String sha1 = null;
	public String url;

	public static String[] getLibNames(Element libNode)
	{
		if (libNode == null)
			return null;
		NodeList list=libNode.getElementsByTagName("lib");
		ArrayList<String> libs = new ArrayList<String>();
		for (int i=0;i<list.getLength();i++)
		{
			if (list.item(i).getNodeType() != Node.ELEMENT_NODE)
				continue;
			Element lib=(Element)list.item(i);
			if (lib!=null)
				libs.add(lib.getAttribute("name"));
		}
		String[] strings = new String[libs.size()];
		return libs.toArray(strings);
	}

	public static NeedsStruct[] getNeeds(Element libNode)
	{
		if (libNode == null)
			return null;
		NodeList list=libNode.getElementsByTagName("item");
		ArrayList<NeedsStruct> needs = new ArrayList<NeedsStruct>();

		for (int i=0;i<list.getLength();i++)
		{
			if (list.item(i).getNodeType() != Node.ELEMENT_NODE)
				continue;
			Element lib=(Element)list.item(i);
			if (lib!=null)
			{
				NeedsStruct need=new NeedsStruct();
				need.name=lib.getAttribute("name");
				need.filePath=lib.getAttribute("file");
				need.url=lib.getAttribute("url");
				need.sha1=lib.getAttribute("sha1");
				need.size=Long.valueOf(lib.getAttribute("size"));
				needs.add(need);
			}
		}
		NeedsStruct[] _needs = new NeedsStruct[needs.size()];
		return needs.toArray(_needs);
	}
	public static  Library getLibrary(Element libNode, boolean includeNeed)
	{
		Library lib= new Library();
		lib.name=libNode.getAttribute("name");
		lib.sha1=libNode.getAttribute("sha1").toUpperCase();
	   	lib.filePath=libNode.getAttribute("file");
	   	lib.url=libNode.getAttribute("url");
	   	try
	   	{
	   		lib.level=Integer.parseInt(libNode.getAttribute("level"));
	   	} catch (Exception e) {
	   		e.printStackTrace();
		}
	   	
	   	try
	   	{
	   		lib.size=Long.parseLong(libNode.getAttribute("size"));
	   	} catch (Exception e) {
	   		e.printStackTrace();
		}
	   	NodeList list=libNode.getElementsByTagName("depends");
	   	for (int i=0;i<list.getLength();i++)
	   	{
			if (list.item(i).getNodeType() != Node.ELEMENT_NODE)
				continue;
	   		lib.depends=getLibNames((Element) list.item(i));
	   		break;
	   	}
	   	list=libNode.getElementsByTagName("replaces");
	   	for (int i=0;i<list.getLength();i++)
	   	{
			if (list.item(i).getNodeType() != Node.ELEMENT_NODE)
				continue;
	   		lib.replaces=getLibNames((Element) list.item(i));
	   		break;
	   	}

	   	if (!includeNeed) // don't waste time.
	   	    return lib;

	   	list=libNode.getElementsByTagName("needs");
	   	for (int i=0;i<list.getLength();i++)
	   	{
			if (list.item(i).getNodeType() != Node.ELEMENT_NODE)
				continue;
	   		lib.needs=getNeeds((Element) list.item(i));
	   		break;
	   	}
		return lib;
	}

};

class NeedsStruct
{
	public String name = null;
	public String filePath = null;
	public String sha1 = null;
	public String url;
	public long size = 0;
};