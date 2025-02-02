//+------------------------------------------------------------------+
//|                                 CONSOLIDATION RANGE BREAKOUT.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh> // Include the trade library
CTrade obj_Trade;          // Create an instance of the CTrade class

#define rangeNAME "CONSOLIDATION RANGE" // Define the name of the consolidation range

datetime TIME1_X1, TIME2_Y2; // Declare datetime variables to hold range start and end times
double PRICE1_Y1, PRICE2_Y2; // Declare double variables to hold range high and low prices

bool isRangeExist = false;                           // Flag to check if the range exists
bool isInRange = false;                              // Flag to check if we are currently within the range
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期

input int rangeBars = 10;        // Number of bars to consider for the range
input int rangeSizePoints = 400; // Maximum range size in points

input double sl_points = 500.0; // Stop loss points
input double tp_points = 500.0; // Take profit points

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //---
    // Initialization code here (we don't initialize anything)
    //---
    obj_Trade.SetExpertMagicNumber(452682);
    return (INIT_SUCCEEDED); // Return initialization success
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //---
    // Deinitialization code here (we don't deinitialize anything)
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //---

    int currBars = iBars(_Symbol, InpTimeframe); // Get the current number of bars
    static int prevBars = currBars;              // Static variable to store the previous number of bars
    static bool isNewBar = false;                // Static flag to check if a new bar has appeared
    if (prevBars == currBars)
    {
        isNewBar = false;
    } // Check if the number of bars has not changed
    else
    {
        isNewBar = true;
        prevBars = currBars;
    } // If the number of bars has changed, set isNewBar to true and update prevBars

    if (isRangeExist == false && isNewBar)
    {                                                                                        // If no range exists and a new bar has appeared
        TIME1_X1 = iTime(_Symbol, InpTimeframe, rangeBars);                                  // Get the start time of the range
        int highestHigh_BarIndex = iHighest(_Symbol, InpTimeframe, MODE_HIGH, rangeBars, 1); // Get the bar index with the highest high in the range
        PRICE1_Y1 = iHigh(_Symbol, InpTimeframe, highestHigh_BarIndex);                      // Get the highest high price in the range

        TIME2_Y2 = iTime(_Symbol, InpTimeframe, 0);                                      // Get the current time
        int lowestLow_BarIndex = iLowest(_Symbol, InpTimeframe, MODE_LOW, rangeBars, 1); // Get the bar index with the lowest low in the range
        PRICE2_Y2 = iLow(_Symbol, InpTimeframe, lowestLow_BarIndex);                     // Get the lowest low price in the range

        isInRange = (PRICE1_Y1 - PRICE2_Y2) / _Point <= rangeSizePoints; // Check if the range size is within the allowed points

        if (isInRange)
        {                                                                                // If the range size is valid
            plotConsolidationRange(rangeNAME, TIME1_X1, PRICE1_Y1, TIME2_Y2, PRICE2_Y2); // Plot the consolidation range
            isRangeExist = true;                                                         // Set the range exist flag to true
            Print("RANGE PLOTTED");                                                      // Print a message indicating the range is plotted
        }
    }

    double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits); // Get and normalize the current Ask price
    double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits); // Get and normalize the current Bid price

    if (isRangeExist && isInRange)
    {                                                                    // If the range exists and we are in range
        double R_HighBreak_Prc = (PRICE2_Y2 + rangeSizePoints * _Point); // Calculate the high breakout price
        double R_LowBreak_Prc = (PRICE1_Y1 - rangeSizePoints * _Point);  // Calculate the low breakout price
        if (Ask > R_HighBreak_Prc)
        {                                                                                        // If the Ask price breaks the high breakout price
            Print("BUY NOW, ASK = ", Ask, ", L = ", PRICE2_Y2, ", H BREAK = ", R_HighBreak_Prc); // Print a message to buy
            isInRange = false;
            isRangeExist = false; // Reset range flags
            if (PositionsTotal() > 0)
            {
                return;
            } // Exit the function
            obj_Trade.Buy(0.01, _Symbol, Ask, Bid - sl_points * _Point, Bid + tp_points * _Point);
            return; // Exit the function
        }
        else if (Bid < R_LowBreak_Prc)
        {                      // If the Bid price breaks the low breakout price
            Print("SELL NOW"); // Print a message to sell
            isInRange = false;
            isRangeExist = false; // Reset range flags
            if (PositionsTotal() > 0)
            {
                return;
            } // Exit the function

            obj_Trade.Sell(0.01, _Symbol, Bid, Ask + sl_points * _Point, Ask - tp_points * _Point);

            return; // Exit the function
        }

        if (Ask > PRICE1_Y1)
        {                                                                                // If the Ask price is higher than the current high price
            PRICE1_Y1 = Ask;                                                             // Update the high price to the Ask price
            TIME2_Y2 = iTime(_Symbol, InpTimeframe, 0);                                  // Update the end time to the current time
            Print("UPDATED RANGE PRICE1_Y1 TO ASK, NEEDS REPLOT");                       // Print a message indicating the range needs to be replotted
            plotConsolidationRange(rangeNAME, TIME1_X1, PRICE1_Y1, TIME2_Y2, PRICE2_Y2); // Replot the consolidation range
        }
        else if (Bid < PRICE2_Y2)
        {                                                                                // If the Bid price is lower than the current low price
            PRICE2_Y2 = Bid;                                                             // Update the low price to the Bid price
            TIME2_Y2 = iTime(_Symbol, InpTimeframe, 0);                                  // Update the end time to the current time
            Print("UPDATED RANGE PRICE2_Y2 TO BID, NEEDS REPLOT");                       // Print a message indicating the range needs to be replotted
            plotConsolidationRange(rangeNAME, TIME1_X1, PRICE1_Y1, TIME2_Y2, PRICE2_Y2); // Replot the consolidation range
        }
        else
        {
            if (isNewBar)
            {                                                                                // If a new bar has appeared
                TIME2_Y2 = iTime(_Symbol, InpTimeframe, 1);                                  // Update the end time to the previous bar time
                Print("EXTEND THE RANGE TO PREV BAR TIME");                                  // Print a message indicating the range is extended
                plotConsolidationRange(rangeNAME, TIME1_X1, PRICE1_Y1, TIME2_Y2, PRICE2_Y2); // Replot the consolidation range
            }
        }
    }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Function to plot the consolidation range                         |
//| rangeName - name of the range object                             |
//| time1_x1 - start time of the range                               |
//| price1_y1 - high price of the range                              |
//| time2_x2 - end time of the range                                 |
//| price2_y2 - low price of the range                               |
//+------------------------------------------------------------------+
void plotConsolidationRange(string rangeName, datetime time1_x1, double price1_y1,
                            datetime time2_x2, double price2_y2)
{
    if (ObjectFind(0, rangeName) < 0)
    {                                                                                           // If the range object does not exist
        ObjectCreate(0, rangeName, OBJ_RECTANGLE, 0, time1_x1, price1_y1, time2_x2, price2_y2); // Create the range object
        ObjectSetInteger(0, rangeName, OBJPROP_COLOR, clrBlue);                                 // Set the color of the range
        ObjectSetInteger(0, rangeName, OBJPROP_FILL, true);                                     // Enable fill for the range
        ObjectSetInteger(0, rangeName, OBJPROP_WIDTH, 5);                                       // Set the width of the range
    }
    else
    {                                                               // If the range object exists
        ObjectSetInteger(0, rangeName, OBJPROP_TIME, 0, time1_x1);  // Update the start time of the range
        ObjectSetDouble(0, rangeName, OBJPROP_PRICE, 0, price1_y1); // Update the high price of the range
        ObjectSetInteger(0, rangeName, OBJPROP_TIME, 1, time2_x2);  // Update the end time of the range
        ObjectSetDouble(0, rangeName, OBJPROP_PRICE, 1, price2_y2); // Update the low price of the range
    }
    ChartRedraw(0); // Redraw the chart to reflect changes
}