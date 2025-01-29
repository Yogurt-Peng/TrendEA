#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 1458341;              // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input int InpRISValue = 10;                          // RSI参数
input int InpGridSpacing = 100;                      // 网格间距
input double InpAdditionMultiple = 2;                // 加仓倍数

//--- 全局变量
int currentLayer = 0;                // 当前加仓层数
ENUM_POSITION_TYPE currentDirection; // 当前持仓方向
ulong lastOrderTicket = 0;           // 最后一次订单的Ticket

class CTrendMartin : public CStrategy
{
private:
    CTools *m_Tools;
    CRSI *m_RSI;

public:
    CTrendMartin(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_RSI = new CRSI(symbol, timeFrame, InpRISValue);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CTrendMartin() {};

    bool Initialize() override
    {
        if (!m_RSI.Initialize())
        {
            // 打印错误码
            Print("RSI初始化失败,错误码:", GetLastError());
            return false;
        }

        ChartIndicatorAdd(0, 1, m_RSI.GetHandle());
        return true;
    };

    SignalType TradeSignal() override
    {
        // buySegnal rsi 上穿越 30
        if (m_RSI.GetValue(2) < 30 && m_RSI.GetValue(1) > 30)
        {
            return BuySignal;
        }

        // sellSignal rsi 下穿越 70
        if (m_RSI.GetValue(2) > 70 && m_RSI.GetValue(1) < 70)
        {
            return SellSignal;
        }

        return NoSignal;
    };
    //+------------------------------------------------------------------+
    //| 核心交易逻辑                                                     |
    //+------------------------------------------------------------------+
    void ExecuteTrade() override
    {
        if (!m_Tools.IsNewBar(PERIOD_M1))
            return;

        // 周五不开仓
        MqlDateTime currentTimeStruct;
        TimeToStruct(TimeCurrent(), currentTimeStruct);
        if (currentTimeStruct.day_of_week == 5) // 5 代表周五
            return;

        // 1. 检查是否有未平仓订单
        if (PositionSelect(m_Symbol))
        {
            // 获取当前持仓类型
            ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            // 获取当前持仓盈亏（以点数为单位）
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            // 计算浮动盈亏点数
            double points;
            if (positionType == POSITION_TYPE_BUY)
                points = (currentPrice - openPrice) / _Point; // 多单盈利计算
            else
                points = (openPrice - currentPrice) / _Point; // 空单盈利计算

            // 2. 判断是否达到止盈或止损
            if (points >= InpGridSpacing)
            {
                // 盈利平仓并重置
                m_Trade.PositionClose(m_Symbol);
                currentLayer = 0;
                return;
            }
            else if (points <= -InpGridSpacing)
            {
                // 亏损达到网格间距，平仓并反向开仓
                m_Trade.PositionClose(m_Symbol);

                if (currentLayer < 6) // 加仓次数小于 5 时继续加仓
                {
                    currentLayer++;
                    // 计算新手数: InpLotSize * (倍数^层数)
                    double newLot = InpLotSize * MathPow(InpAdditionMultiple, currentLayer);
                    // 切换方向
                    ENUM_ORDER_TYPE newDirection = (positionType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                    // 开反向订单
                    if (newDirection == ORDER_TYPE_BUY)
                        m_Trade.Buy(newLot, m_Symbol, SymbolInfoDouble(m_Symbol, SYMBOL_ASK), 0, 0);
                    else
                        m_Trade.Sell(newLot, m_Symbol, SymbolInfoDouble(m_Symbol, SYMBOL_BID), 0, 0);
                }
                else // 加仓次数达到 5 时全部止损
                {
                    m_Trade.PositionClose(m_Symbol);
                    currentLayer = 0;
                    return;
                }
            }
        }
        else
        {
            SignalType signal = TradeSignal();
            if (signal == NoSignal)
                return;
            // 无持仓时开首单（假设初始方向为Buy，可根据信号调整）
            if (signal == BuySignal)
                m_Trade.Buy(InpLotSize, m_Symbol, SymbolInfoDouble(m_Symbol, SYMBOL_ASK), 0, 0);
            else
                m_Trade.Sell(InpLotSize, m_Symbol, SymbolInfoDouble(m_Symbol, SYMBOL_BID), 0, 0);
            currentDirection = signal == BuySignal ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            currentLayer = 0;
        }
    }
    //+------------------------------------------------------------------+
    //| 开仓函数（含止盈止损设置）                                       |
    //+------------------------------------------------------------------+

    void OnDeinit(const int reason)
    {
        IndicatorRelease(m_RSI.GetHandle());
        delete m_RSI;
        delete m_Tools;
    };
};

CTrendMartin *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{

    g_Strategy = new CTrendMartin(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize strategy!");
        return INIT_FAILED;
    }
    return (INIT_SUCCEEDED);
}

void OnTick()
{
    g_Strategy.OnTick();
}

void OnDeinit(const int reason)
{
    g_Strategy.OnDeinit(reason);
}
