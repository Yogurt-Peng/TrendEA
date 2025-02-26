
class CDraw
{
public:
    CDraw() {};
    ~CDraw() {};

    void DrawLabel(string name, string text, int x, int y, color col = clrRed, int fontsize = 10, int sub_window = 0, ENUM_BASE_CORNER anchor_point = CORNER_LEFT_UPPER)
    {
        if (ObjectCreate(0, name, OBJ_LABEL, sub_window, 0, 0))
        {
            // 设置中心坐标为左上角
            ObjectSetInteger(0, name, OBJPROP_CORNER, anchor_point);
            // ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
            ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
            ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
            ObjectSetInteger(0, name, OBJPROP_COLOR, col);
            ObjectSetString(0, name, OBJPROP_TEXT, text);
        }
        else
            Print("Failed to create the object OBJ_LABEL ", name, ", Error code = ", GetLastError());
    };

    // 绘制文本数组
    void DrawLabels(string name, string &text[], int lineCount, int x, int y, color col = clrRed, int fontsize = 10, int sub_window = 0, ENUM_BASE_CORNER anchor_point = CORNER_LEFT_UPPER)
    {

        // 删除所有同名的对象
        for (int i = 0; i < lineCount; i++)
        {
            ObjectDelete(0, name + IntegerToString(i));
        }

        for (int i = 0; i < lineCount; i++)
        {
            DrawLabel(name + IntegerToString(i), text[i], x, y + i * 20, col, fontsize, sub_window, anchor_point);
        }
    };

    void DrawRectangleFill(string name, int x1, double y1, int x2, double y2, color col = clrRed, int width = 1, int sub_window = 0)
    {

        if (ObjectCreate(0, name, OBJ_RECTANGLE, sub_window, x1, y1, x2, y2))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, col);
            //--- 设置矩形线的宽度
            ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
            //--- 启用 (true) 或禁用 (false) 填充矩形的模式
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
        }
    };

    void DrawHorizontalLine(string name, double y1, color col = clrRed, int width = 1, int sub_window = 0)
    {
        if (y1 <= 0)
            return;
        if (ObjectCreate(0, name, OBJ_HLINE, sub_window, 0, y1))
        {
            //--- 设置线的颜色
            ObjectSetInteger(0, name, OBJPROP_COLOR, col);
            //--- 设置线的宽度
            ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        }
    };
};