using System;
using System.Xml;
using System.Xml.Serialization;
using System.IO;
using System.Text;

class Program
{
  static int Main(string[] args)
  {
    var serializer = new XmlSerializer(typeof(SvgDocument));

    return 0;
  }
}

public class SvgDocument
{

}