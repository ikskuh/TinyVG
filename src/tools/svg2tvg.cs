using System;
using System.Xml;
using System.Collections.Specialized;
using System.Collections.Generic;
using System.Xml.Serialization;
using System.IO;
using System.Text;
using System.Drawing;
using System.Diagnostics;
using System.Linq;
using System.Globalization;

class Program
{
  static int Main(string[] args)
  {
    CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
    var serializer = new XmlSerializer(typeof(SvgDocument));

    var render_png = false;
    var render_tga = true;

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

    var banned_files = new HashSet<string>
    {
      // Banned for: using exponent floats.
      // "distributor-logo-midnightbsd.svg",
      // "twitter.svg",
      // "cadence.svg",
    };

    int count = 0;
    int unsupported_count = 0;
    int crash_count = 0;

    int total_svg_size = 0;
    int total_tvg_size = 0;
    int total_png_size = 0;

    try
    {
      var src_root = "/home/felix/projects/forks/";
      var dst_root = "/tmp/converted/";
      foreach (var folder in new string[] {
        // src_root + "/zig-logo",
        // src_root + "/MaterialDesign/svg",
        src_root + "/papirus-icon-theme/Papirus/48x48/actions",
        src_root + "/papirus-icon-theme/Papirus/48x48/apps",
        // src_root + "/papirus-icon-theme/Papirus/48x48/devices",
        // src_root + "/papirus-icon-theme/Papirus/48x48/emblems",
        // src_root + "/papirus-icon-theme/Papirus/48x48/emotes",
        // src_root + "/papirus-icon-theme/Papirus/48x48/mimetypes",
        // src_root + "/papirus-icon-theme/Papirus/48x48/places",
        // src_root + "/papirus-icon-theme/Papirus/48x48/status",
       })
      {
        foreach (var file in Directory.GetFiles(folder, "*.svg"))
        {
          if (banned_files.Contains(Path.GetFileName(file)))
            continue;
          try
          {
            var dst_file = dst_root + Path.GetFileName(Path.GetDirectoryName(file)) + "/" + Path.GetFileNameWithoutExtension(file) + ".tvg";

            Console.WriteLine("parse {0} => {1}", Path.GetFileName(file), dst_file);
            SvgDocument doc;
            bool fully_supported = true;
            int svg_size;
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
                svg_size = (int)stream.Position;
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

            if (!fully_supported) continue;

            byte[] tvg_data;
            try
            {
              tvg_data = ConvertToTvg(doc);
            }
            catch (UnitRangeException exception)
            {
              Console.WriteLine("Failed to parse {0}", file);
              var pad = "";
              Exception e = exception;
              while (e != null)
              {
                Console.Error.WriteLine("{0}{1}", pad, e.Message);
                pad = pad + " ";
                e = e.InnerException;
              }
              continue;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(dst_file));
            File.WriteAllBytes(dst_file, tvg_data);

            if (render_png) Process.Start("convert", file + " " + Path.ChangeExtension(dst_file, ".original.png")).WaitForExit();

            if (render_tga)
            {
              Process.Start("zig-out/bin/tvg-render", dst_file).WaitForExit();
              Process.Start("convert", Path.ChangeExtension(dst_file, ".tga") + " " + Path.ChangeExtension(dst_file, ".render.png")).WaitForExit();
            }

            int tvg_size = tvg_data.Length;
            int png_size = render_png ? File.ReadAllBytes(Path.ChangeExtension(dst_file, ".original.png")).Length : 0;

            Console.WriteLine("SVG: {0}\t(100%)\tTVG: {1}\t({2}%),\tPNG: {3}\t(%{4})",
              svg_size,
              tvg_size,
              (100 * tvg_size / svg_size),
              png_size,
              (100 * png_size / svg_size)
            );
            total_svg_size += svg_size;
            total_tvg_size += tvg_size;
            total_png_size += png_size;
          }
          catch (Exception ex)
          {
            Console.WriteLine("Failed to translate {0}", file);
            if (!(ex is NotSupportedException))
            {
              Process.Start("timg", file).WaitForExit();
              Console.WriteLine(ex);
              return 1;
              crash_count += 1;
            }
          }
        }
      }
    }
    finally
    {
      Console.WriteLine("{0} icons parsed successfully, of which {1} are not fully supported and of which {2} crashed.", count, unsupported_count, crash_count);

      if (unknown_styles.Count > 0)
      {
        Console.WriteLine("Found unknown style keys:");
        foreach (var kvp in unknown_styles)
        {
          Console.Write("\t{0} =>", kvp.Key);
          foreach (var value in kvp.Value)
          {
            Console.Write(" '{0}'", value);
          }
          Console.WriteLine();
        }
      }
      if (total_svg_size > 0)
      {
        Console.WriteLine("SVG: {0}\t(100%)\tTVG: {1}\t({2}%),\tPNG: {3}\t(%{4})",
          total_svg_size,
          total_tvg_size,
          (100 * total_tvg_size / total_svg_size),
          total_png_size,
          (100 * total_png_size / total_svg_size)
        );
      }
    }
    return 0;
  }

  static byte[] ConvertToTvg(SvgDocument document)
  {
    var intermediate_buffer = new AnalyzeIntermediateBuffer();

    AnalyzeNode(intermediate_buffer, document);

    var result = intermediate_buffer.Finalize(document);

    document.TvgFillStyle = new TvgFlatColor
    {
      Color = Color.Magenta,
    };

    // this loop will only execute when a coordinate won't fit the target range.
    // The next lower scale is then selected and it's retried.
    while (true)
    {
      try
      {
        // Console.WriteLine("Use scale factor {0} for size limit {1}", 1 << scale_bits, coordinate_limit);
        var ms = new MemoryStream();

        ms.Write(new byte[] { 0x72, 0x56 }); // magic
        ms.Write(new byte[] { 0x01 }); // version

        ms.Write(new byte[] {
          (byte)(result. scale_bits & 0x0F),
        });

        ms.Write(BitConverter.GetBytes((ushort)result.image_width));
        ms.Write(BitConverter.GetBytes((ushort)result.image_height));
        ms.Write(BitConverter.GetBytes((ushort)result.color_table.Length));
        foreach (var col in result.color_table)
        {
          ms.Write(new byte[4]
          {
            (byte)col.R,
            (byte)col.G,
            (byte)col.B,
            (byte)col.A,
          });
        }

        // Console.WriteLine("Found {0} colors in {1} nodes!", result.color_table.Length, intermediate_buffer.node_count);

        var pos_pre = ms.Position;
        {
          var stream = new TvgStream { stream = ms, ar = result };
          TranslateNodes(result, stream, document);
        }
        if (pos_pre == ms.Position)
        {
          throw new NotSupportedException("This SVG does not contain any supported elements!");
        }

        ms.Write(new byte[] { 0x00 }); // end of document

        return ms.ToArray();
      }
      catch (UnitRangeException ex)
      {
        if (result.scale_bits == 0)
          throw;
        Console.WriteLine("Reducing bit range trying to fit {0}", ex.Value);
        result.scale_bits -= 1;
      }
    }
  }

  public static float ToFloat(string s)
  {
    return float.Parse(s, CultureInfo.InvariantCulture);
  }

  static void TranslateNodes(AnalyzeResult data, TvgStream stream, SvgNode node)
  {
    if (node is SvgGroup group)
    {
      foreach (var child in group.Nodes ?? new SvgNode[0])
      {
        TranslateNodes(data, stream, child);
      }
      return;
    }
    if (node.TvgFillStyle == null && node.TvgLineStyle == null)
      return;

    if (node is SvgPolygon polygon)
    {
      var points = polygon.Points
        .Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries)
        .Select(s => s.Split(','))
        .Select(a => new PointF(ToFloat(a[0]), ToFloat(a[1])))
        .ToArray();

      stream.WriteCommand(TvgCommand.fill_polygon);
      stream.WriteCountAndStyleType(points.Length, polygon.TvgFillStyle);
      stream.WriteStyle(polygon.TvgFillStyle);
      foreach (var pt in points)
      {
        stream.WritePoint(pt);
      }
    }
    else if (node is SvgPath path)
    {
      var renderer = new TvgPathRenderer(stream, node.TvgFillStyle);
      // SvgPathParser.Parse(path.Data, new SvgDebugRenderer());
      SvgPathParser.Parse(path.Data, renderer);
      renderer.Finish();
    }
    else if (node is SvgRectangle rect)
    {
      if (rect.RadiusX != 0 || rect.RadiusY == 0)
      {
        if (rect.Width >= 2 * rect.RadiusX && rect.Height >= 2 * rect.RadiusY)
        {
          var dx = rect.Width - 2 * rect.RadiusX;
          var dy = rect.Height - 2 * rect.RadiusY;

          var rx = rect.RadiusX;
          var ry = rect.RadiusY;
          var rx5 = 0.5f * rx;
          var ry5 = 0.5f * ry;

          var renderer = new TvgPathRenderer(stream, node.TvgFillStyle);
          // SvgPathParser.Parse(path.Data, new SvgDebugRenderer());
          SvgPathParser.Parse($"M {rect.X} {rect.Y} m {rx} 0 h {dx} c {rx5} 0 {rx} 0 {rx} {ry} v {dy} c 0 {ry} -{rx} {ry} -{rx} {ry} h -{dx} c -{rx5} 0 -{rx} 0 -{rx} -{ry} v -{dy} c 0 -{ry} {rx5} -{ry} {rx} -{ry}", renderer);
          renderer.Finish();
          return;
        }

        Console.WriteLine("Rounded rectangles not supported yet!");

      }


      stream.WriteCommand(TvgCommand.fill_rectangles);
      stream.WriteCountAndStyleType(1, rect.TvgFillStyle);
      stream.WriteStyle(rect.TvgFillStyle);
      stream.WriteCoordX(rect.X);
      stream.WriteCoordY(rect.Y);
      stream.WriteCoordX(rect.Width);
      stream.WriteCoordY(rect.Height);

    }
    else
    {
      Console.WriteLine("Not implemented: {0}", node.GetType().Name);
    }
  }

  class TvgPathRenderer : IPathRenderer
  {
    TvgStream out_stream;

    TvgStream temp_stream;
    TvgStyle fill_style;

    List<int> segments = new List<int>();

    int CurrentSegmentPrimitives
    {
      get => segments[segments.Count - 1];
      set => segments[segments.Count - 1] = value;
    }

    public TvgPathRenderer(TvgStream target, TvgStyle fill_style)
    {
      this.out_stream = target ?? throw new ArgumentNullException();
      this.temp_stream = new TvgStream { stream = new MemoryStream(), ar = target.ar };
      this.fill_style = fill_style ?? throw new ArgumentNullException();
      this.segments.Add(0);
    }

    public void Finish()
    {
      var filled_segments = segments.Where(l => l > 0).ToArray();
      if (filled_segments.Length > 0)
      {
        out_stream.WriteCommand(TvgCommand.fill_path);
        out_stream.WriteCountAndStyleType(filled_segments.Length, fill_style);
        out_stream.WriteStyle(fill_style);

        foreach (var seg_len in filled_segments)
        {
          out_stream.WriteUnsignedInt((uint)seg_len);
        }

        out_stream.Write(((MemoryStream)temp_stream.stream).ToArray());
      }
    }

    public void MoveTo(PointF pt)
    {
      //  Console.WriteLine("MoveTo({0},{1})", pt.X, pt.Y);
      if (CurrentSegmentPrimitives > 0)
        segments.Add(0);
      temp_stream.WritePoint(pt);
    }
    public void LineTo(PointF pt)
    {
      // Console.WriteLine("LineTo({0},{1})", pt.X, pt.Y);
      CurrentSegmentPrimitives += 1;
      temp_stream.WriteByte(0);
      temp_stream.WritePoint(pt);
    }
    public void VerticalTo(float y)
    {
      // Console.WriteLine("VerticalTo({0})", y);
      CurrentSegmentPrimitives += 1;
      temp_stream.WriteByte(2);
      temp_stream.WriteCoordY(y);
    }
    public void HorizontalTo(float x)
    {
      // Console.WriteLine("HorizontalTo({0})", x);
      CurrentSegmentPrimitives += 1;
      temp_stream.WriteByte(1);
      temp_stream.WriteCoordX(x);
    }
    public void QuadCurveTo(PointF pt1, PointF pt2)
    {
      // Console.WriteLine("QuadCurveTo({0},{1},{2},{3})", pt1.X, pt1.Y, pt2.X, pt2.Y);
      CurrentSegmentPrimitives += 1;
      temp_stream.WriteByte(7);
      temp_stream.WritePoint(pt1);
      temp_stream.WritePoint(pt1);
    }
    public void CurveTo(PointF pt1, PointF pt2, PointF pt3)
    {
      // Console.WriteLine("CurveTo({0},{1},{2},{3},{4},{5})", pt1.X, pt1.Y, pt2.X, pt2.Y, pt3.X, pt3.Y);
      CurrentSegmentPrimitives += 1;
      temp_stream.WriteByte(3);
      temp_stream.WritePoint(pt1);
      temp_stream.WritePoint(pt2);
      temp_stream.WritePoint(pt3);
    }
    public void ArcTo(PointF size, float angle, bool isLarge, bool sweep, PointF ep)
    {
      // Console.WriteLine("ArcTo()");
      if (size.X == 0 || size.Y == 0)
      {
        LineTo(ep);
        return;
      }
      CurrentSegmentPrimitives += 1;
      temp_stream.WriteByte(5);
      temp_stream.WriteByte((byte)(0 |
        (isLarge ? 1 : 0) |
        (sweep ? 0 : 2)
      ));
      temp_stream.WriteUnit(size.X);
      temp_stream.WriteUnit(size.Y);
      temp_stream.WriteUnit(angle);
      temp_stream.WritePoint(ep);
    }

    public void ClosePath()
    {
      CurrentSegmentPrimitives += 1;
      // Console.WriteLine("ClosePath()");
      temp_stream.WriteByte(6);
    }
  }

  static Color? AnalyzeStyleDef(AnalyzeIntermediateBuffer buf, string fill, float opacity)
  {
    if (fill.StartsWith("#"))
      return buf.InsertColor(fill, opacity);
    else if (fill != "none")
      throw new NotSupportedException();
    else
      return null;

  }
  static Dictionary<string, HashSet<string>> unknown_styles = new Dictionary<string, HashSet<string>>();

  static void AnalyzeNode(AnalyzeIntermediateBuffer buf, SvgNode node, string indent = "")
  {
    buf.node_count += 1;

    var style = new NameValueCollection();
    if (node.Style != null)
    {
      foreach (var kvp in node.Style.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries).Select(s => s.Split(':')).ToDictionary(
       a => a[0].Trim().ToLower(),
       a => a[1].Trim()
     ))
      {
        style[kvp.Key] = kvp.Value;
      }
    }

    if (node.Fill != null)
      style["fill"] = node.Fill;
    if (node.Opacity != 1)
      style["opacity"] = node.Opacity.ToString();

    float opacity = ToFloat(style["opacity"] ?? "1");


    foreach (string key in style.AllKeys)
    {
      switch (key)
      {
        case "fill":
        case "opacity":
        case "stroke":
        case "fill-opacity":
        case "stroke-opacity":
          break;
        default:
          if (!unknown_styles.TryGetValue(key, out var set))
            unknown_styles.Add(key, set = new HashSet<string>());
          set.Add(style[key]);
          break;
      }
    }

    var fill = style["fill"];
    if (fill != null)
    {
      float fill_opacity = opacity * ToFloat(style["fill-opacity"] ?? "1");
      var color = AnalyzeStyleDef(buf, fill, fill_opacity);
      if (color != null)
      {
        node.TvgFillStyle = new TvgFlatColor { Color = color.Value };
      }
    }

    var stroke = style["stroke"];
    if (stroke != null)
    {
      float stroke_opacity = opacity * ToFloat(style["stroke-opacity"] ?? "1");
      var color = AnalyzeStyleDef(buf, stroke, stroke_opacity);
      if (color != null)
      {
        node.TvgLineStyle = new TvgFlatColor { Color = color.Value };
      }
    }

    if (node is SvgGroup group)
    {
      foreach (var child in group.Nodes ?? new SvgNode[0])
      {
        child.Parent = node;
        AnalyzeNode(buf, child, indent + " ");
      }
    }
    else
    {
      if (node.TvgFillStyle == null)
      {
        node.TvgFillStyle = new TvgFlatColor { Color = buf.InsertColor("#000", 1.0f) };
      }
    }

    // Console.WriteLine(
    //   "{5}Analyzed {0} with {1} ({2}) and {3} ({4})",
    //   node.GetType().Name,
    //   node.TvgFillStyle?.ToString() ?? "<null>", fill ?? "<null>",
    //   node.TvgLineStyle?.ToString() ?? "<null>", stroke ?? "<null>",
    //   indent);
  }

  public static Color AdjustColor(Color c, float a)
  {
    return Color.FromArgb(
      (int)(c.A * a),
      (int)(c.R * a),
      (int)(c.G * a),
      (int)(c.B * a));
  }

  public static void Assert(bool b)
  {
    if (!b) throw new InvalidOperationException("Assertion failed!");
  }
}

public enum TvgCommand : byte
{
  end_of_document = 0,

  fill_polygon = 1,
  fill_rectangles = 2,
  fill_path = 3,

  draw_lines = 4,
  draw_line_loop = 5,
  draw_line_strip = 6,
  draw_line_path = 7,

  outline_fill_polygon = 8,
  outline_fill_rectangles = 9,
  outline_fill_path = 10,

};

public class AnalyzeIntermediateBuffer
{
  HashSet<Color> colors = new HashSet<Color>();

  public int node_count = 0;

  public Color InsertColor(string text, float opacity)
  {
    Color color;
    switch (text)
    {
      case "#value_dark": color = Color.Black; break;
      case "#value_middle": color = Color.Silver; break;
      case "#value_light": color = Color.White; break;
      default:
        color = ColorTranslator.FromHtml(text);
        break;
    }
    color = Program.AdjustColor(color, opacity);
    colors.Add(color);
    return color;
  }

  public AnalyzeResult Finalize(SvgDocument doc)
  {
    int width = doc.Width;
    int height = doc.Height;

    float[] viewport = doc.ViewBox?.Split(' ').Select(Program.ToFloat).ToArray() ?? new float[] {
      0, 0, width, height,
    };

    Program.Assert(viewport.Length == 4);

    if (width == 0 && height == 0)
    {
      width = (int)viewport[2];
      height = (int)viewport[3];
    }

    // determine the maximum precision for the given image size
    int coordinate_limit = Math.Max(width, height);
    int scale_bits = 0;
    while (scale_bits < 15 && (coordinate_limit << (scale_bits + 1)) < 32768)
    {
      scale_bits += 1;
    }
    Program.Assert(scale_bits < 16);


    if (colors.Count == 0)
    {
      colors.Add(Color.FromArgb(0, 0, 0));
    }
    return new AnalyzeResult
    {
      scale_bits = scale_bits,
      color_table = colors.ToArray(),
      image_width = width,
      image_height = height,
      viewport_x = viewport[0],
      viewport_y = viewport[1],
      viewport_width = viewport[2],
      viewport_height = viewport[3],
    };
  }
}

public class AnalyzeResult
{
  public int scale_bits;
  public Color[] color_table;

  public int image_width;
  public int image_height;

  public float viewport_x;
  public float viewport_y;
  public float viewport_width;
  public float viewport_height;

  public float viewport_scale_x;
  public float viewport_scale_y;

  public ushort GetColorIndex(Color color)
  {
    for (ushort i = 0; i < color_table.Length; i++)
    {
      if (color_table[i] == color)
        return i;
    }
    throw new ArgumentOutOfRangeException("color", $"color {color} was not previously registered!");
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
  public float X { get; set; }

  [XmlAttribute("y")]
  public float Y { get; set; }

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
  public float Opacity { get; set; } = 1.0f;

  [XmlAttribute("fill-opacity")]
  public float FillOpacity { get; set; } = 1.0f;

  [XmlAttribute("overflow")]
  public string Overflow { get; set; }

  [XmlAttribute("stroke")]
  public string Stroke { get; set; }

  [XmlAttribute("stroke-width")]
  public float StrokeWidth { get; set; }

  [XmlAttribute("stroke-miterlimit")]
  public float StrokeMiterLimit { get; set; }

  [XmlAttribute("stroke-linecap")]
  public string StrokeLineCap { get; set; }

  [XmlAttribute("stroke-linejoin")]
  public string StrokeLineJoin { get; set; }

  [XmlAttribute("clip-path")]
  public string ClipPath { get; set; }

  [XmlAttribute("shape-rendering")]
  public string ShapeRendering { get; set; }

  [XmlAttribute("fill-rule")]
  public string FillRule { get; set; }

  [XmlAttribute("clip-rule")]
  public string ClipRule { get; set; }

  // TVG Implementation starts here

  public SvgNode Parent { get; set; }

  TvgStyle local_fill_style = null;
  public TvgStyle TvgFillStyle
  {
    get { return local_fill_style ?? Parent?.TvgFillStyle; }
    set { local_fill_style = value; }
  }

  TvgStyle local_line_style = null;
  public TvgStyle TvgLineStyle
  {
    get { return local_line_style ?? Parent?.TvgLineStyle; }
    set { local_line_style = value; }
  }
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
}


// width="28" height="28" x="16" y="16" rx="2.211" ry="2.211" transform="matrix(0,1,1,0,0,0)"
public class SvgRectangle : SvgNode
{
  [XmlAttribute("x")]
  public float X { get; set; }

  [XmlAttribute("y")]
  public float Y { get; set; }

  [XmlAttribute("width")]
  public float Width { get; set; }

  [XmlAttribute("height")]
  public float Height { get; set; }

  [XmlAttribute("rx")]
  public float RadiusX { get; set; }

  [XmlAttribute("ry")]
  public float RadiusY { get; set; }
}

// cx="12" cy="24" r="4"
public class SvgCircle : SvgNode
{
  [XmlAttribute("cx")]
  public float X { get; set; }

  [XmlAttribute("cy")]
  public float Y { get; set; }

  [XmlAttribute("r")]
  public float Radius { get; set; }

}
// cx="-10.418" cy="28.824" rx="4.856" ry="8.454" transform="matrix(0.70812504,-0.70608705,0.51863379,0.85499649,0,0)"
public class SvgEllipse : SvgNode
{
  [XmlAttribute("cx")]
  public float X { get; set; }

  [XmlAttribute("cy")]
  public float Y { get; set; }

  [XmlAttribute("r")]
  public float Radius { get { throw new NotSupportedException(); } set { RadiusX = value; RadiusY = value; } }

  [XmlAttribute("rx")]
  public float RadiusX { get; set; }

  [XmlAttribute("ry")]
  public float RadiusY { get; set; }
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

public class TvgStream
{
  public Stream stream;
  public AnalyzeResult ar;

  public void WriteByte(byte b)
  {
    stream.WriteByte(b);
  }

  public void WriteUnit(float value)
  {
    int scale = (1 << ar.scale_bits);
    int unit = (int)(value * scale + 0.5);
    if (unit < short.MinValue || unit > short.MaxValue)
      throw new UnitRangeException(value, unit, scale);
    stream.Write(BitConverter.GetBytes((short)unit));
  }

  public void WriteSizeX(float x)
  {
    WriteUnit(x / (ar.viewport_width / ar.image_width));
  }

  public void WriteCoordX(float x)
  {
    WriteSizeX(x - ar.viewport_x);
  }

  public void WriteSizeY(float y)
  {
    WriteUnit(y / (ar.viewport_height / ar.image_height));
  }

  public void WriteCoordY(float y)
  {
    WriteSizeY(y - ar.viewport_y);
  }

  public void WritePoint(float x, float y)
  {
    WriteCoordX(x);
    WriteCoordY(y);
  }

  public void WritePoint(PointF f) => WritePoint(f.X, f.Y);

  public void WriteColorIndex(Color c)
  {
    WriteUnsignedInt(ar.GetColorIndex(c));
  }

  public void WriteUnsignedInt(uint val)
  {
    if (val == 0)
    {
      stream.WriteByte(0);
      return;
    }
    while (val != 0)
    {
      byte mask = 0x00;
      if (val > 0x7F)
        mask = 0x80;
      stream.WriteByte((byte)((val & 0x7F) | mask));
      val >>= 7;
    }
  }

  public void WriteCommand(TvgCommand cmd) => WriteByte((byte)cmd);
  public void WriteCountAndStyleType(int count, TvgStyle style)
  {
    if (count > 64)
      throw new NotSupportedException($"Cannot encode {count} elements!");
    if (count == 0) throw new ArgumentOutOfRangeException("Cannot encode 0 path elements!");
    WriteByte((byte)((style.GetStyleType() << 6) | ((count == 64) ? 0 : count)));
  }

  public void WriteStyle(TvgStyle style) => style.WriteData(ar, this);

  public void Write(byte[] buffer)
  {
    stream.Write(buffer);
  }
}

public abstract class TvgStyle
{
  public abstract byte GetStyleType();
  public abstract void WriteData(AnalyzeResult ar, TvgStream stream);
}

public class TvgFlatColor : TvgStyle
{
  public Color Color;

  public override byte GetStyleType() => 0;

  public override void WriteData(AnalyzeResult ar, TvgStream stream)
  {
    stream.WriteUnsignedInt(ar.GetColorIndex(Color));
  }

  public override string ToString() => Color.ToString();
}

public abstract class TvgGradient : TvgStyle
{
  public PointF StartPosition;
  public PointF EndPosition;

  public Color StartColor;
  public Color EndColor;

  public override void WriteData(AnalyzeResult ar, TvgStream stream)
  {
    stream.WritePoint(StartPosition);
    stream.WritePoint(EndPosition);
    stream.WriteUnsignedInt(ar.GetColorIndex(StartColor));
    stream.WriteUnsignedInt(ar.GetColorIndex(EndColor));
  }
}

public class TvgLinearGradient : TvgGradient
{
  public override byte GetStyleType() => 1;
  public override string ToString() => "[Linear Gradient]";
}

public class TvgRadialGradient : TvgGradient
{
  public override byte GetStyleType() => 2;
  public override string ToString() => "[Radial Gradient]";
}

public interface IPathRenderer
{
  void MoveTo(PointF pt);
  void LineTo(PointF pt);
  void VerticalTo(float y);
  void HorizontalTo(float x);
  void QuadCurveTo(PointF pt1, PointF pt2);
  void CurveTo(PointF pt1, PointF pt2, PointF pt3);
  void ArcTo(PointF size, float angle, bool isLarge, bool sweep, PointF ep);
  void ClosePath();
}

// Free after
// https://www.w3.org/TR/SVG2/paths.html#PathDataBNF
public class SvgPathParser
{
  public static void Parse(string str, IPathRenderer renderer)
  {
    var parser = new SvgPathParser(str, renderer);
    try
    {
      parser.ParsePath();
    }
    catch
    {
      parser.PrintContext("Error Context");
      throw;
    }
  }

  readonly string path_text;
  readonly IPathRenderer renderer;

  int char_offset = 0;

  PointF current_position = new PointF(0, 0);
  PointF? stored_control_point = null;

  private SvgPathParser(string str, IPathRenderer renderer)
  {
    this.path_text = str;
    this.renderer = renderer;
  }


  bool EndOfString => (char_offset >= path_text.Length);

  void PrintContext(string prefix)
  {
    var len = path_text.Length - char_offset;
    var rest = (len > 40) ? path_text.Substring(char_offset, 40) + "…" : path_text.Substring(char_offset);
    Console.WriteLine("{0}: '{1}\u0332{2}'", prefix, path_text.Substring(0, char_offset), rest);
  }

  char? PeekChar()
  {
    if (EndOfString)
      return null;
    return path_text[char_offset];
  }

  char GetChar()
  {
    if (EndOfString)
      throw new EndOfStreamException("No more characters!");
    var c = path_text[char_offset];
    char_offset += 1;
    return c;
  }

  struct ParserState
  {
    public SvgPathParser self;
    public int offset;
    public void Restore()
    {
      self.char_offset = offset;
    }
    public string Slice()
    {
      return self.path_text.Substring(offset, self.char_offset - offset);
    }
  }

  ParserState Save()
  {
    return new ParserState { self = this, offset = char_offset };
  }

  char AcceptChar(string list) => AcceptChar(list.ToCharArray());

  char AcceptChar(params char[] list)
  {
    var c = GetChar();
    if (!list.Contains(c))
      throw new Exception("Unexpected char '" + c + "', expected one of " + string.Join(", ", list));
    return c;
  }

  char? PeekAny(string list) => PeekAny(list.ToCharArray());

  char? PeekAny(params char[] list)
  {
    var c = PeekChar();
    if (c == null)
      return null;
    if (list.Contains(c.Value))
      return c;
    return null;
  }

  static PointF Add(PointF a, PointF b) => new PointF(a.X + b.X, a.Y + b.Y);

  PointF MoveCursor(float dx, float dy, bool relative) => MoveCursor(new PointF(dx, dy), relative);
  float MoveCursorX(float dx, bool relative) => MoveCursor(new PointF(dx, relative ? 0.0f : current_position.Y), relative).X;
  float MoveCursorY(float dy, bool relative) => MoveCursor(new PointF(relative ? 0.0f : current_position.X, dy), relative).Y;

  PointF MoveCursor(PointF pt, bool relative)
  {
    current_position = MakeAbsolute(pt, relative);
    return current_position;
  }

  PointF MakeAbsolute(PointF pt, bool relative)
  {
    if (relative)
      return Add(current_position, pt);
    else
      return pt;
  }

  // svg_path::= wsp* moveto? (moveto drawto_command*)?
  void ParsePath()
  {
    SkipWhitespace();

    ParseMoveTo();

    while (!EndOfString)
    {
      SkipWhitespace();
      if (EndOfString)
        break;
      ParseDrawToCommand();
    }
  }

  // drawto_command::=
  //     moveto
  //     | closepath
  //     | lineto
  //     | horizontal_lineto
  //     | vertical_lineto
  //     | curveto
  //     | smooth_curveto
  //     | quadratic_bezier_curveto
  //     | smooth_quadratic_bezier_curveto
  //     | elliptical_arc
  void ParseDrawToCommand()
  {
    var c = PeekChar();
    if (c == null) throw new InvalidOperationException();
    switch (c.Value)
    {
      case 'Z':
      case 'z':
        ParseClosePath();
        break;
      case 'M':
      case 'm':
        ParseMoveTo();
        break;
      case 'L':
      case 'l':
        ParseLineTo();
        break;
      case 'H':
      case 'h':
        ParseHorizontalLineTo();
        break;
      case 'V':
      case 'v':
        ParseVerticalLineTo();
        break;
      case 'C':
      case 'c':
        ParseCurveTo();
        break;
      case 'S':
      case 's':
        ParseSmoothCurveTo();
        break;
      case 'Q':
      case 'q':
        ParseQuadraticBezierTo();
        break;
      case 'T':
      case 't':
        ParseSmoothQuadraticBezierTo();
        break;
      case 'A':
      case 'a':
        ParseArcTo();
        break;

      default:
        throw new ArgumentException("Unexpected character: " + c.Value);
    }
  }

  // closepath::=
  //     ("Z" | "z")
  void ParseClosePath()
  {
    AcceptChar('Z', 'z');
    SkipWhitespace();
  }

  // moveto::=
  //     ( "M" | "m" ) wsp* coordinate_pair_sequence
  void ParseMoveTo()
  {
    bool relative = (AcceptChar('M', 'm') == 'm');
    SkipWhitespace();
    foreach (var pair in ParseCoordinatePairSequence())
    {
      renderer.MoveTo(MoveCursor(pair, relative));
    }
  }

  // lineto::=
  //     ("L"|"l") wsp* coordinate_pair_sequence
  void ParseLineTo()
  {
    var relative = (AcceptChar('L', 'l') == 'l');
    SkipWhitespace();
    foreach (var pair in ParseCoordinatePairSequence())
    {
      renderer.LineTo(MoveCursor(pair, relative));
    }
  }

  // horizontal_lineto::=
  //     ("H"|"h") wsp* coordinate_sequence
  void ParseHorizontalLineTo()
  {
    var relative = (AcceptChar('H', 'h') == 'h');
    SkipWhitespace();
    foreach (var x in ParseCoordinateSequence())
    {
      renderer.HorizontalTo(MoveCursorX(x, relative));
    }
  }

  // vertical_lineto::=
  //     ("V"|"v") wsp* coordinate_sequence
  void ParseVerticalLineTo()
  {
    var relative = (AcceptChar('V', 'v') == 'v');
    SkipWhitespace();
    foreach (var y in ParseCoordinateSequence())
    {
      renderer.VerticalTo(MoveCursorY(y, relative));
    }
  }

  // curveto::=
  //     ("C"|"c") wsp* curveto_coordinate_sequence

  // curveto_coordinate_sequence::=
  //     coordinate_pair_triplet
  //     | (coordinate_pair_triplet comma_wsp? curveto_coordinate_sequence)

  void ParseCurveTo()
  {
    var relative = (AcceptChar('C', 'c') == 'c');
    SkipWhitespace();
    foreach (var tup in ParseCoordinatePairTupleSequence(3))
    {
      var cp0 = MakeAbsolute(tup[0], relative);
      var cp1 = MakeAbsolute(tup[1], relative);
      var dest = MoveCursor(tup[2], relative);
      renderer.CurveTo(cp0, cp1, dest);
      stored_control_point = Add(current_position, new PointF(cp1.X - dest.X, cp1.Y - dest.Y));
    }
  }

  // smooth_curveto::=
  //     ("S"|"s") wsp* smooth_curveto_coordinate_sequence

  // smooth_curveto_coordinate_sequence::=
  //     coordinate_pair_double
  //     | (coordinate_pair_double comma_wsp? smooth_curveto_coordinate_sequence)

  void ParseSmoothCurveTo()
  {
    var relative = (AcceptChar('S', 's') == 's');
    SkipWhitespace();
    foreach (var tup in ParseCoordinatePairTupleSequence(2))
    {
      var cp1 = MakeAbsolute(tup[0], relative);
      var dest = MoveCursor(tup[1], relative);
      renderer.CurveTo(stored_control_point ?? current_position, cp1, dest);
      stored_control_point = Add(current_position, new PointF(cp1.X - dest.X, cp1.Y - dest.Y));
    }
  }

  // quadratic_bezier_curveto::=
  //     ("Q"|"q") wsp* quadratic_bezier_curveto_coordinate_sequence

  // quadratic_bezier_curveto_coordinate_sequence::=
  //     coordinate_pair_double
  //     | (coordinate_pair_double comma_wsp? quadratic_bezier_curveto_coordinate_sequence)

  void ParseQuadraticBezierTo()
  {
    var relative = (AcceptChar('Q', 'q') == 'q');
    SkipWhitespace();
    foreach (var tup in ParseCoordinatePairTupleSequence(2))
    {
      var cp = MakeAbsolute(tup[0], relative);
      var dest = MoveCursor(tup[1], relative);
      renderer.QuadCurveTo(cp, dest);
      stored_control_point = Add(current_position, new PointF(cp.X - dest.X, cp.Y - dest.Y));
    }
  }

  // smooth_quadratic_bezier_curveto::=
  //     ("T"|"t") wsp* coordinate_pair_sequence
  void ParseSmoothQuadraticBezierTo()
  {
    var relative = (AcceptChar('T', 't') == 't');
    SkipWhitespace();
    foreach (var dest_loc in ParseCoordinatePairSequence())
    {
      var cp = stored_control_point ?? current_position;
      var dest = MoveCursor(dest_loc, relative);
      renderer.QuadCurveTo(cp, dest);
      stored_control_point = Add(current_position, new PointF(cp.X - dest.X, cp.Y - dest.Y));
    }
  }

  struct EllipseArg
  {
    public float radius_x;
    public float radius_y;
    public float angle;
    public bool large_arc;
    public bool sweep;
    public PointF target;
  }

  // elliptical_arc::=
  //     ( "A" | "a" ) wsp* elliptical_arc_argument_sequence

  void ParseArcTo()
  {
    var relative = (AcceptChar('A', 'a') == 'a');
    SkipWhitespace();
    foreach (var args in ParseEllipseArgSequence())
    {
      renderer.ArcTo(
        new PointF(args.radius_x, args.radius_y),
        args.angle,
        args.large_arc,
        args.sweep,
        MoveCursor(args.target, relative)
      );
    }
  }

  // elliptical_arc_argument_sequence::=
  //     elliptical_arc_argument
  //     | (elliptical_arc_argument comma_wsp? elliptical_arc_argument_sequence)

  IEnumerable<EllipseArg> ParseEllipseArgSequence()
  {
    yield return ParseEllipseArgument();
    while (true)
    {
      var loc = Save();
      EllipseArg p;
      try
      {
        SkipCommaWhitespace();
        p = ParseEllipseArgument();
      }
      catch
      {
        loc.Restore();
        yield break;
      }
      yield return p;
    }
  }


  // elliptical_arc_argument::=
  //     number comma_wsp? number comma_wsp? number comma_wsp
  //     flag comma_wsp? flag comma_wsp? coordinate_pair
  EllipseArg ParseEllipseArgument()
  {
    var loc = Save();

    try
    {
      var result = new EllipseArg();
      result.radius_x = ParseCoordinate();
      SkipCommaWhitespace();
      result.radius_y = ParseCoordinate();
      SkipCommaWhitespace();
      result.angle = ParseCoordinate();
      SkipCommaWhitespace(false);
      result.large_arc = ParseFlag();
      SkipCommaWhitespace();
      result.sweep = ParseFlag();
      SkipCommaWhitespace();
      result.target = ParseCoordinatePair();
      return result;
    }
    catch
    {
      loc.Restore();
      throw;
    }
  }

  // coordinate_pair_double::=
  //     coordinate_pair comma_wsp? coordinate_pair
  // coordinate_pair_triplet::=
  //     coordinate_pair comma_wsp? coordinate_pair comma_wsp? coordinate_pair

  IEnumerable<PointF[]> ParseCoordinatePairTupleSequence(int tuple_size)
  {
    yield return ParseCoordinatePairTuple(tuple_size);
    while (true)
    {
      var loc = Save();
      PointF[] p;
      try
      {
        SkipCommaWhitespace();
        p = ParseCoordinatePairTuple(tuple_size);
      }
      catch
      {
        loc.Restore();
        yield break;
      }
      yield return p;
    }
  }

  PointF[] ParseCoordinatePairTuple(int tuple_size)
  {
    var tuple = new PointF[tuple_size];
    var loc = Save();
    tuple[0] = ParseCoordinatePair();
    try
    {
      for (int i = 1; i < tuple_size; i++)
      {
        SkipCommaWhitespace();
        tuple[i] = ParseCoordinatePair();
      }
      return tuple;
    }
    catch
    {
      loc.Restore();
      throw;
    }
  }

  // coordinate_pair_sequence::=
  //     coordinate_pair | (coordinate_pair comma_wsp? coordinate_pair_sequence)
  IEnumerable<PointF> ParseCoordinatePairSequence()
  {
    yield return ParseCoordinatePair();
    while (true)
    {
      var loc = Save();
      PointF p;
      try
      {
        SkipWhitespace();
        p = ParseCoordinatePair();
      }
      catch
      {
        loc.Restore();
        yield break;
      }
      yield return p;
    }
  }

  // coordinate_sequence::=
  //     coordinate | (coordinate comma_wsp? coordinate_sequence)
  IEnumerable<float> ParseCoordinateSequence()
  {
    yield return ParseCoordinate();
    while (true)
    {
      var loc = Save();
      float v;
      try
      {
        SkipWhitespace();
        v = ParseCoordinate();
      }
      catch
      {
        loc.Restore();
        yield break;
      }
      yield return v;
    }
  }

  // coordinate_pair::= coordinate comma_wsp? coordinate
  PointF ParseCoordinatePair()
  {
    var loc = Save();
    try
    {
      float x = ParseCoordinate();
      SkipCommaWhitespace();
      float y = ParseCoordinate();
      return new PointF(x, y);
    }
    catch
    {
      loc.Restore();
      throw;
    }
  }

  // coordinate::= sign? number
  // sign::= "+"|"-"
  float ParseCoordinate()
  {
    return ParseNumberGeneric(true);
  }

  // number ::= ([0-9])+
  float ParseNumber()
  {
    return ParseNumberGeneric(false);
  }

  float ParseNumberGeneric(bool allow_sign)
  {
    var begin = Save();
    char? c = AcceptChar("0123456789." + (allow_sign ? "+-" : ""));
    if (c != '.')
    {
      while (true)
      {
        c = PeekAny("0123456789.");
        if (c == null)
          return ParseFloat(begin.Slice());
        AcceptChar("0123456789.");
        if (c.Value == '.')
          break;
      }
    }
    while (true)
    {
      c = PeekAny("0123456789");
      if (c == null)
        return ParseFloat(begin.Slice());
      AcceptChar("0123456789");
    }
  }

  static float ParseFloat(string str)
  {
    try
    {
      return float.Parse(str, CultureInfo.InvariantCulture);
    }
    catch
    {
      Console.WriteLine("Float Context: '{0}'", str);
      throw;
    }
  }

  // flag::=("0"|"1")
  bool ParseFlag()
  {
    return (AcceptChar("01") == '1');
  }

  // wsp ::= (#x9 | #x20 | #xA | #xC | #xD)
  // comma_wsp ::= (wsp+ ","? wsp*) | ("," wsp*)

  const string valid_whitespace = "\x09\x20\x0A\x0C\x0D";

  void SkipCommaWhitespace() => SkipCommaWhitespace(true);

  void SkipCommaWhitespace(bool allow_empty)
  {
    var first = true;
    while (true)
    {
      var c = PeekAny(valid_whitespace + ",");

      if (c == null)
      {
        if (!allow_empty && first)
          throw new InvalidOperationException("Expected whitespace or comma!");
        return;
      }
      first = false;
      GetChar();
      if (c.Value == ',')
        break;
    }
    SkipWhitespace();
  }

  void SkipWhitespace()
  {
    while (true)
    {
      if (PeekAny(valid_whitespace + ",") == null)
        return;
      GetChar();
    }
  }
}


class SvgDebugRenderer : IPathRenderer
{
  public void MoveTo(PointF pt)
  {
    Console.WriteLine("MoveTo({0},{1})", pt.X, pt.Y);
  }
  public void LineTo(PointF pt)
  {
    Console.WriteLine("LineTo({0},{1})", pt.X, pt.Y);
  }
  public void VerticalTo(float y)
  {
    Console.WriteLine("VerticalTo({0})", y);
  }
  public void HorizontalTo(float x)
  {
    Console.WriteLine("HorizontalTo({0})", x);
  }
  public void QuadCurveTo(PointF pt1, PointF pt2)
  {
    Console.WriteLine("QuadCurveTo({0},{1},{2},{3})", pt1.X, pt1.Y, pt2.X, pt2.Y);
  }
  public void CurveTo(PointF pt1, PointF pt2, PointF pt3)
  {
    Console.WriteLine("CurveTo({0},{1},{2},{3},{4},{5})", pt1.X, pt1.Y, pt2.X, pt2.Y, pt3.X, pt3.Y);
  }
  public void ArcTo(PointF size, float angle, bool isLarge, bool sweep, PointF ep)
  {
    Console.WriteLine("ArcTo({0},{1},{2},{3},{4},{5},{6})", size.X, size.Y, angle, isLarge, sweep, ep.X, ep.Y);
  }
  public void ClosePath()
  {
    Console.WriteLine("ClosePath()");
  }
}

[System.Serializable]
public class UnitRangeException : System.Exception
{

  public UnitRangeException(float value, int unit, int scale) :
  base(string.Format("{0} is out of range when encoded as {1} with scale {2}", value, unit, scale))
  {
    this.Value = value;
  }
  protected UnitRangeException(
      System.Runtime.Serialization.SerializationInfo info,
      System.Runtime.Serialization.StreamingContext context) : base(info, context) { }

  public float Value { get; }
}