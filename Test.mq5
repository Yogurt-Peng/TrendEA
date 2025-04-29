#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "---->海龟交易法";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpMagicNumber = 1231523;                  // 基础魔术号
input int InpMaxAddition = 2;                        // 最大加仓次数
input int InpLotType = 2;                            // 1:手数,2:百分比
input double InpLotSize = 0.01;                      // 手数
input double InpMaxRisk = 4.0;                       // 每个头寸的风险百分比
input int InpEntryDCPeriod = 20;                     // 入场DC周期
input int InpExitDCPeriod = 10;                      // 出场DC周期
input int InpATRPeriod = 14;                         // ATR周期
input double InpSLATRMultiplier = 2.0;               // 止损ATR倍数
input double InpAddATRMultiplier = 0.5;              // 波动多少倍加仓
input bool InpLong = true;                           // 做多
input bool InpShort = true;                          // 做空

CTrade g_Trade;
CTools *g_Tools;
CATR *g_ATR;
CDonchian *g_DCEntry;
CDonchian *g_DCExit;

int OnInit()
{
       g_Tools = new CTools(_Symbol, &g_Trade);
       g_ATR = new CATR(_Symbol, InpTimeframe, InpATRPeriod);
       g_DCEntry = new CDonchian(_Symbol, InpTimeframe, InpEntryDCPeriod);
       g_DCExit = new CDonchian(_Symbol, InpTimeframe, InpExitDCPeriod);

       g_Trade.SetExpertMagicNumber(InpMagicNumber);

       if (!g_ATR.Initialize() || !g_DCEntry.Initialize() || !g_DCExit.Initialize())
              return (INIT_FAILED);
       ChartIndicatorAdd(0, 0, g_DCEntry.GetHandle());
       ChartIndicatorAdd(0, 1, g_ATR.GetHandle());
       EventSetTimer(10); // 设置定时器，每10秒执行一次OnTimer函数

       return (INIT_SUCCEEDED);
}

void OnTick()
{
       // 设置ATR指标颜色
       PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrRed);
       // // 设置DC指标颜色
       // PlotIndexSetInteger(g_DCEntry.GetHandle(), 0, PLOT_LINE_COLOR, clrBlue);  // 上轨
       // PlotIndexSetInteger(g_DCEntry.GetHandle(), 1, PLOT_LINE_COLOR, clrGreen); // 下轨

       // PlotIndexSetInteger(g_DCExit.GetHandle(), 0, PLOT_LINE_COLOR, clrOrange); // 上轨
       // PlotIndexSetInteger(g_DCExit.GetHandle(), 1, PLOT_LINE_COLOR, clrPurple); // 下轨
}