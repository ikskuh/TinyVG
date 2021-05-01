using System;
using System.Xml;
using System.Collections.Generic;
using System.Xml.Serialization;
using System.IO;
using System.Text;
using System.Diagnostics;

class Program
{
  static int Main(string[] args)
  {
    var serializer = new XmlSerializer(typeof(SvgDocument));

    var unsupported_attribs = new HashSet<string>{
      "class", // no support for SVG classes
      "font-weight",
      "letter-spacing",
      "word-spacing",
      "vector-effect",
      "display",
      "preserveAspectRatio",
    };

    var unsupported_elements = new HashSet<string>{
      "defs", // no support for predefined styles
      "use",
    };

    int count = 0;
    int unsupported_count = 0;
    try
    {
      foreach (var folder in new string[] {
      "/home/felix/projects/forks/MaterialDesign/svg",
      "/home/felix/projects/forks/papirus-icon-theme/Papirus/48x48/actions",
      "/home/felix/projects/forks/papirus-icon-theme/Papirus/48x48/apps",
      "/home/felix/projects/forks/papirus-icon-theme/Papirus/48x48/devices",
      "/home/felix/projects/forks/papirus-icon-theme/Papirus/48x48/emblems",
      "/home/felix/projects/forks/papirus-icon-theme/Papirus/48x48/emotes",
      "/home/felix/projects/forks/papirus-icon-theme/Papirus/48x48/mimetypes",
      "/home/felix/projects/forks/papirus-icon-theme/Papirus/48x48/places",
      "/home/felix/projects/forks/papirus-icon-theme/Papirus/48x48/status",
       })
      {
        foreach (var file in Directory.GetFiles(folder, "*.svg"))
        {
          Console.WriteLine("parse {0}", Path.GetFileName(file));
          SvgDocument doc;
          bool fully_supported = true;
          try
          {
            using (var stream = File.OpenRead(file))
            {
              var events = new XmlDeserializationEvents();
              events.OnUnknownElement = new XmlElementEventHandler((object sender, XmlElementEventArgs e) =>
              {
                if (unsupported_elements.Contains(e.Element.Name))
                {
                  fully_supported = false;
                  return;
                }
                throw new InvalidOperationException(string.Format("Unknown element {0}", e.Element.Name));
              });
              events.OnUnknownAttribute = new XmlAttributeEventHandler((object sender, XmlAttributeEventArgs e) =>
              {
                if (e.Attr.Prefix == "xml")
                  return;
                if (unsupported_attribs.Contains(e.Attr.Name))
                {
                  fully_supported = false;
                  return;
                }
                throw new InvalidOperationException(string.Format("Unknown attribute {0}", e.Attr.Name));
              });
              using (var reader = XmlReader.Create(stream, new XmlReaderSettings
              {
                DtdProcessing = DtdProcessing.Ignore,
              }))
              {
                doc = (SvgDocument)serializer.Deserialize(reader, events);
              }
            }
          }
          catch (Exception exception)
          {
            Console.WriteLine("Failed to parse {0}", file);
            Process.Start("timg", file).WaitForExit();
            var pad = "";
            var e = exception;
            while (e != null)
            {
              Console.Error.WriteLine("{0}{1}", pad, e.Message);
              pad = pad + " ";
              e = e.InnerException;
            }
            return 1;
          }
          count += 1;
          if (!fully_supported) unsupported_count += 1;
        }
      }
    }
    finally
    {
      Console.WriteLine("{0} icons parsed successfully, of which {1} are not fully supported", count, unsupported_count);
    }
    return 0;
  }

}

[XmlRoot("svg", Namespace = "http://www.w3.org/2000/svg")]
public class SvgDocument : SvgGroup
{
  [XmlAttribute("version")]
  public string Version { get; set; }

  [XmlAttribute("viewBox")]
  public string ViewBox { get; set; }

  [XmlAttribute("x")]
  public double X { get; set; }

  [XmlAttribute("y")]
  public double Y { get; set; }

  [XmlAttribute("width")]
  public int Width { get; set; }

  [XmlAttribute("height")]
  public int Height { get; set; }
}

// style="opacity:0.5;fill:#ffffff"
// overflow="visible"
// stroke="#fff" stroke-linecap="round" stroke-linejoin="round" stroke-width="4"
public class SvgNode
{
  [XmlAttribute("id")]
  public string ID { get; set; }

  [XmlAttribute("style")]
  public string Style { get; set; }

  [XmlAttribute("transform")]
  public string Transform { get; set; }

  [XmlAttribute("fill")]
  public string Fill { get; set; }

  [XmlAttribute("opacity")]
  public double Opacity { get; set; } = 1.0;

  [XmlAttribute("fill-opacity")]
  public double FillOpacity { get; set; } = 1.0;

  [XmlAttribute("overflow")]
  public Overflow Overflow { get; set; }

  [XmlAttribute("stroke")]
  public string Stroke { get; set; }

  [XmlAttribute("stroke-width")]
  public double StrokeWidth { get; set; }

  [XmlAttribute("stroke-miterlimit")]
  public double StrokeMiterLimit { get; set; }

  [XmlAttribute("stroke-linecap")]
  public LineCap StrokeLineCap { get; set; }

  [XmlAttribute("stroke-linejoin")]
  public LineJoin StrokeLineJoin { get; set; }

  [XmlAttribute("clip-path")]
  public string ClipPath { get; set; }
}

public enum Overflow
{
  [XmlEnum("visible")] Visible,
}

public class SvgGroup : SvgNode
{
  [XmlElement("path", typeof(SvgPath))]
  [XmlElement("rect", typeof(SvgRectangle))]
  [XmlElement("circle", typeof(SvgCircle))]
  [XmlElement("ellipse", typeof(SvgEllipse))]
  [XmlElement("style", typeof(SvgStyle))]
  [XmlElement("polygon", typeof(SvgPolygon))]
  [XmlElement("polyline", typeof(SvgPolyline))]
  [XmlElement("g", typeof(SvgGroup))]
  public SvgNode[] Nodes { get; set; }
}

// fill="#fff" opacity=".2"
// d="M 21 21 L 21 29 L 25 29 L 25 25 L 29 25 L 29 21 L 25 21 L 21 21 z M 31 21 L 31 25 L 35 25 L 35 29 L 39 29 L 39 21 L 35 21 L 31 21 z M 21 31 L 21 39 L 25 39 L 29 39 L 29 35 L 25 35 L 25 31 L 21 31 z M 35 31 L 35 35 L 31 35 L 31 39 L 35 39 L 39 39 L 39 31 L 35 31 z"
// fill-rule="evenodd"
public class SvgPath : SvgNode
{
  [XmlAttribute("d")]
  public string Data { get; set; }

  [XmlAttribute("fill-rule")]
  public FillRule FillRule { get; set; } = FillRule.EvenOdd;

}

public enum FillRule
{
  [XmlEnum("evenodd")] EvenOdd,
}

public enum LineCap
{
  [XmlEnum("round")] Round,
  [XmlEnum("square")] Square,
}

public enum LineJoin
{
  [XmlEnum("round")] Round,
  [XmlEnum("bevel")] Bevel,
}

// width="28" height="28" x="16" y="16" rx="2.211" ry="2.211" transform="matrix(0,1,1,0,0,0)"
public class SvgRectangle : SvgNode
{
  [XmlAttribute("x")]
  public double X { get; set; }

  [XmlAttribute("y")]
  public double Y { get; set; }

  [XmlAttribute("width")]
  public double Width { get; set; }

  [XmlAttribute("height")]
  public double Height { get; set; }

  [XmlAttribute("rx")]
  public double RadiusX { get; set; } = 0.0;

  [XmlAttribute("ry")]
  public double RadiusY { get; set; } = 0.0;
}

// cx="12" cy="24" r="4"
public class SvgCircle : SvgNode
{
  [XmlAttribute("cx")]
  public double X { get; set; }

  [XmlAttribute("cy")]
  public double Y { get; set; }

  [XmlAttribute("r")]
  public double Radius { get; set; }

}
// cx="-10.418" cy="28.824" rx="4.856" ry="8.454" transform="matrix(0.70812504,-0.70608705,0.51863379,0.85499649,0,0)"
public class SvgEllipse : SvgNode
{
  [XmlAttribute("cx")]
  public double X { get; set; }

  [XmlAttribute("cy")]
  public double Y { get; set; }

  [XmlAttribute("r")]
  public double Radius { get { throw new NotSupportedException(); } set { RadiusX = value; RadiusY = value; } }

  [XmlAttribute("rx")]
  public double RadiusX { get; set; }

  [XmlAttribute("ry")]
  public double RadiusY { get; set; }
}

public class SvgStyle : SvgNode
{
  [XmlAttribute("type")]
  public string MimeType { get; set; }

  [XmlText]
  public string Content { get; set; }
}

public class SvgPolygon : SvgNode
{
  [XmlAttribute("points")]
  public string Points { get; set; }
}

public class SvgPolyline : SvgNode
{
  [XmlAttribute("points")]
  public string Points { get; set; }
}