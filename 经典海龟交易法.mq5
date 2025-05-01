#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "---->海龟交易法";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H2; // 周期
input int InpMagicNumber = 1231523;             // 基础魔术号
input int InpMaxAddition = 2;                   // 最大加仓次数
input int InpLotType = 2;                       // 1:手数,2:百分比
input double InpLotSize = 0.01;                 // 手数
input double InpMaxRisk = 2.0;                  // 每个头寸的风险百分比
input int InpEntryDCPeriod = 20;                // 入场DC周期
input int InpExitDCPeriod = 10;                 // 出场DC周期
input int InpATRPeriod = 40;                    // ATR周期
input double InpSLATRMultiplier = 2.0;          // 止损ATR倍数
input double InpAddATRMultiplier = 0.5;         // 波动多少倍加仓
input bool InpLong = true;                      // 做多
input bool InpShort = true;                     // 做空

enum SignalType
{
    BuySignal,
    SellSignal,
    NoSignal
};

CTrade g_Trade;
CTools *g_Tools;
CATR *g_ATR;
CDonchian *g_DCEntry;
SignalType g_Direction; // 交易方向

int g_PositionSize;
double g_LastEntryPrice;
double g_EntryATR;

int OnInit()
{
    g_Tools = new CTools(_Symbol, &g_Trade);
    g_ATR = new CATR(_Symbol, InpTimeframe, InpATRPeriod);
    g_DCEntry = new CDonchian(_Symbol, InpTimeframe, InpEntryDCPeriod);
    g_Trade.SetExpertMagicNumber(InpMagicNumber);

    if (!g_ATR.Initialize() || !g_DCEntry.Initialize())
        return (INIT_FAILED);

    // ChartIndicatorAdd(0, 1, g_ATR.GetHandle());
    ChartIndicatorAdd(0, 0, g_DCEntry.GetHandle());
    EventSetTimer(10); // 设置定时器，每10秒执行一次OnTimer函数

    return (INIT_SUCCEEDED);
}

void OnTick()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double atrValue = g_ATR.GetValue(1);
    g_PositionSize = g_Tools.GetPositionCount(InpMagicNumber);

    // 加仓逻辑
    if (g_PositionSize > 0 && g_PositionSize <= InpMaxAddition)
    {
        if (g_Direction == BuySignal && (ask - g_LastEntryPrice) >= InpAddATRMultiplier * g_EntryATR)
        {
            AddPosition(ask, ask - InpSLATRMultiplier * atrValue, g_Direction, "Buy Addition");
        }
        else if (g_Direction == SellSignal && (g_LastEntryPrice - bid) >= InpAddATRMultiplier * g_EntryATR)
        {
            AddPosition(bid, bid + InpSLATRMultiplier * atrValue, g_Direction, "Sell Addition");
        }
    }

    // if (!g_Tools.IsPastSeconds(5))
    //     return;

    if (!g_Tools.IsNewBar(PERIOD_M1))
        return;

    // 出场逻辑,追钟止损
    g_Tools.ApplyTrailingStopByHighLow(InpExitDCPeriod, InpMagicNumber);

    // 初始入场逻辑
    if (g_PositionSize == 0)
    {

        SignalType signal = TradeSignal();
        if (signal == BuySignal && InpLong)
        {
            OpenPosition(ask, ask - InpSLATRMultiplier * atrValue, signal, "Buy Entry");
        }
        else if (signal == SellSignal && InpShort)
        {
            OpenPosition(bid, bid + InpSLATRMultiplier * atrValue, signal, "Sell Entry");
        }
    }
}

void OnTimer()
{
    string sym = _Symbol;
    string tf = EnumToString(InpTimeframe);
    string lotMode = InpLotType == 1 ? "固定手数" : "ATR倍数";
    string isAutoTrade = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 1 ? "开启算法交易" : "算法交易被关闭";

    string direction;

    if (InpLong && InpShort)
        direction = "做多做空";
    else if (InpLong)
        direction = "做多";
    else if (InpShort)
        direction = "做空";

    double price = iClose(_Symbol, InpTimeframe, 1);
    double sl = price - InpSLATRMultiplier * g_ATR.GetValue(1);
    double lotSize = g_Tools.CalcLots(price, sl, InpMaxRisk);
    // 打印品种和计算出的手数,打印ATR， 打印是否开启了算法交易
    Print(sym, " | ", tf, " | ", lotMode, " | ", lotSize, " | ", isAutoTrade, " | ", InpEntryDCPeriod, " | ", InpExitDCPeriod, " | ", g_PositionSize, " | ", direction);
}

SignalType TradeSignal()
{

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if (ask > g_DCEntry.Upper(0))
        return BuySignal;
    if (bid < g_DCEntry.Lower(0))
        return SellSignal;
    return NoSignal;
}

void OpenPosition(double price, double sl, SignalType direction, string comment)
{
    g_Direction = direction;
    double lotSize = 0;
    if (InpLotType == 2)
        lotSize = g_Tools.CalcLots(price, sl, InpMaxRisk);
    else
        lotSize = InpLotSize;

    if (g_Direction == BuySignal)
        g_Trade.Buy(lotSize, _Symbol, price, sl, 0, comment);
    else if (g_Direction == SellSignal)
        g_Trade.Sell(lotSize, _Symbol, price, sl, 0, comment);

    g_LastEntryPrice = price;
    g_EntryATR = g_ATR.GetValue(1);
    g_PositionSize++;
}
// 修改所有订单止损
void ChangeAllOrderSLTP(double sl)
{
    CPositionInfo positionInfo;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (positionInfo.SelectByIndex(i) && positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == _Symbol)
        {
            if (!g_Trade.PositionModify(positionInfo.Ticket(), sl, 0))
            {
                Print(_Symbol, "|", InpMagicNumber, " Failed to modify SL, Error: ", g_Trade.ResultRetcodeDescription());
            }
        }
    }
}

// 加仓
void AddPosition(double price, double sl, SignalType direction, string comment)
{
    OpenPosition(price, sl, direction, comment);
    ChangeAllOrderSLTP(sl);
    Print(comment);
}
