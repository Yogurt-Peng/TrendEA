//+------------------------------------------------------------------+
//|                                                          BOS.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
input int InpStopLoss = 100;   // 止损点数 0:不使用
input int InpTakeProfit = 100; // 止盈点数 0:不使用
#include <Trade/Trade.mqh>
CTrade obj_Trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() { return (INIT_SUCCEEDED); }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

    static bool isNewBar = false;
    int currBars = iBars(_Symbol, _Period);
    static int prevBars = currBars;
    if (prevBars == currBars)
    {
        isNewBar = false;
    }
    else if (prevBars != currBars)
    {
        isNewBar = true;
        prevBars = currBars;
    }

    const int length = 5;
    const int limit = 5;

    int right_index, left_index;
    bool isSwingHigh = true, isSwingLow = true;
    static double swing_H = -1.0, swing_L = -1.0;
    int curr_bar = limit;

    if (isNewBar)
    {
        for (int j = 1; j <= length; j++)
        {
            right_index = curr_bar - j;
            left_index = curr_bar + j;
            // Print("Current Bar Index = ",curr_bar," ::: Right index: ",right_index,", Left index: ",left_index);
            // Print("curr_bar(",curr_bar,") right_index = ",right_index,", left_index = ",left_index);
            //  If high of the current bar curr_bar is <= high of the bar at right_index (to the left),
            // or if it’s < high of the bar at left_index (to the right), then isSwingHigh is set to false
            // This means that the current bar curr_bar does not have a higher high compared
            // to its neighbors, and therefore, it’s not a swing high
            if ((high(curr_bar) <= high(right_index)) || (high(curr_bar) < high(left_index)))
            {
                isSwingHigh = false;
            }
            if ((low(curr_bar) >= low(right_index)) || (low(curr_bar) > low(left_index)))
            {
                isSwingLow = false;
            }
        }
        // By the end of the loop, if isSwingHigh is still true, it suggests that
        // current bar curr_bar has a higher high than the surrounding bars within
        // length range, marking a potential swing high.

        if (isSwingHigh)
        {
            swing_H = high(curr_bar);
            Print("UP @ BAR INDEX ", curr_bar, " of High: ", high(curr_bar));
            drawSwingPoint(TimeToString(time(curr_bar)), time(curr_bar), high(curr_bar), 77, clrBlue, -1);
        }
        if (isSwingLow)
        {
            swing_L = low(curr_bar);
            Print("DOWN @ BAR INDEX ", curr_bar, " of Low: ", low(curr_bar));
            drawSwingPoint(TimeToString(time(curr_bar)), time(curr_bar), low(curr_bar), 77, clrRed, 1);
        }
    }

    double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
    double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

    if (swing_H > 0 && Bid > swing_H && close(1) > swing_H)
    {
        Print("BREAK UP NOW");
        int swing_H_index = 0;
        for (int i = 0; i <= length * 2 + 1000; i++)
        {
            double high_sel = high(i);
            if (high_sel == swing_H)
            {
                swing_H_index = i;
                Print("BREAK HIGH @ BAR ", swing_H_index);
                break;
            }
        }
        drawBreakLevel(TimeToString(time(0)), time(swing_H_index), high(swing_H_index),
                       time(0 + 1), high(swing_H_index), clrBlue, -1);

        swing_H = -1.0;

        //--- Open Buy
        obj_Trade.Buy(0.01, _Symbol, Ask, Bid - InpStopLoss * _Point, Bid + InpTakeProfit * _Point, "BoS Break Up BUY");

        return;
    }
    else if (swing_L > 0 && Ask < swing_L && close(1) < swing_L)
    {
        Print("BREAK DOWN NOW");
        int swing_L_index = 0;
        for (int i = 0; i <= length * 2 + 1000; i++)
        {
            double low_sel = low(i);
            if (low_sel == swing_L)
            {
                swing_L_index = i;
                Print("BREAK LOW @ BAR ", swing_L_index);
                break;
            }
        }
        drawBreakLevel(TimeToString(time(0)), time(swing_L_index), low(swing_L_index),
                       time(0 + 1), low(swing_L_index), clrRed, 1);

        swing_L = -1.0;

        //--- Open Sell
        obj_Trade.Sell(0.01, _Symbol, Bid, Ask + InpStopLoss * _Point, Ask - InpTakeProfit * _Point, "BoS Break Down SELL");

        return;
    }
}
//+------------------------------------------------------------------+

double high(int index) { return (iHigh(_Symbol, _Period, index)); }
double low(int index) { return (iLow(_Symbol, _Period, index)); }
double close(int index) { return (iClose(_Symbol, _Period, index)); }
datetime time(int index) { return (iTime(_Symbol, _Period, index)); }

void drawSwingPoint(string objName, datetime time, double price, int arrCode,
                    color clr, int direction)
{

    if (ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
        ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrCode);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
        if (direction > 0)
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
        if (direction < 0)
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);

        string txt = " BoS";
        string objNameDescr = objName + txt;
        ObjectCreate(0, objNameDescr, OBJ_TEXT, 0, time, price);
        ObjectSetInteger(0, objNameDescr, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objNameDescr, OBJPROP_FONTSIZE, 10);
        if (direction > 0)
        {
            ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
        }
        if (direction < 0)
        {
            ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
            ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
        }
    }
    ChartRedraw(0);
}

void drawBreakLevel(string objName, datetime time1, double price1,
                    datetime time2, double price2, color clr, int direction)
{
    if (ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_ARROWED_LINE, 0, time1, price1, time2, price2);
        ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
        ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);

        string txt = " Break   ";
        string objNameDescr = objName + txt;
        ObjectCreate(0, objNameDescr, OBJ_TEXT, 0, time2, price2);
        ObjectSetInteger(0, objNameDescr, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objNameDescr, OBJPROP_FONTSIZE, 10);
        if (direction > 0)
        {
            ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
            ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
        }
        if (direction < 0)
        {
            ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
            ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
        }
    }
    ChartRedraw(0);
}