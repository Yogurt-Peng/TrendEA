#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
#include "include/Draw.mqh"

input group "----->美日参数";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 5424524;              // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input double InpUpLimit = 160;                       // 上限
input double InpDownLimit = 140;                     // 下限
input int InpGridCount = 30;

class CGrid : public CStrategy
{
private:
    CTools *m_Tools;
    CDraw m_Draw;
    double m_GridLevels[];  // 存储所有网格价格层级
    bool m_PendingOrders[]; // 挂单状态
    int m_Digits;           // 品种小数位数
    double m_Point;         // 品种点值

    void InitGridLevels()
    {
        double step = (InpUpLimit - InpDownLimit) / (InpGridCount - 1);
        ArrayResize(m_GridLevels, InpGridCount);
        ArrayResize(m_PendingOrders, InpGridCount);
        for (int i = 0; i < InpGridCount; i++)
        {
            m_GridLevels[i] = InpUpLimit - step * i;
            m_PendingOrders[i] = true;
        }

        // 初始化品种精度参数
        m_Digits = (int)SymbolInfoInteger(m_Symbol, SYMBOL_DIGITS);
        m_Point = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
    }

    double GetTakeProfitPrice(int level)
    {
        if (level < InpGridCount - 1)
            return m_GridLevels[level + 1];
        return m_GridLevels[level] - (m_GridLevels[0] - m_GridLevels[1]);
    }

    bool IsSamePrice(double price1, double price2)
    {
        return MathAbs(NormalizeDouble(price1, m_Digits) - NormalizeDouble(price2, m_Digits)) < (m_Point * 0.5);
    }

public:
    CGrid(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber)
        : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        m_Tools = new CTools(symbol, &m_Trade);
        InitGridLevels();
    };

    ~CGrid()
    {
        delete m_Tools;
    };

    void ClearOldGrids()
    {
        for (int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
        {
            string name = ObjectName(0, i);
            if (StringFind(name, "GridLine_") == 0)
                ObjectDelete(0, name);
        }
    }

    void OnTick() override
    {
        if (m_Tools.IsNewBar(m_Timeframe))
        {
            ClearOldGrids();
            for (int i = 0; i < InpGridCount; i++)
            {
                string lineName = "GridLine_" + IntegerToString(i);
                // m_Draw.DrawHorizontalLine(lineName, m_GridLevels[i],
                //                           (i % 2 == 0) ? clrPink : clrGreenYellow, 1, 0);
            }
        }
        if (!m_Tools.IsNewBar(PERIOD_M1))
        {
            return;
        }

        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);

        // 挂单逻辑
        for (int i = InpGridCount - 1; i >= 0; i--)
        {
            if (m_GridLevels[i] > ask && !m_PendingOrders[i])
            {
                double tp_price = GetTakeProfitPrice(i);
                if (m_Trade.SellLimit(InpLotSize, NormalizeDouble(m_GridLevels[i], m_Digits), m_Symbol, 0, NormalizeDouble(tp_price, m_Digits), ORDER_TIME_GTC, 0, "GridOrder_" + IntegerToString(i)))
                {
                    m_PendingOrders[i] = true;
                    Print("SellLimit挂单成功 价格:", m_GridLevels[i], " TP:", tp_price);
                }
                else
                {
                    Print("挂单失败! 错误:", GetLastError());
                }
            }
        }

        int orderIndex[3]; // 最多允许3个挂单
        int orderNumber = 0;
        for (int i = InpGridCount - 1; i >= 0; i--)
        {

            if (m_GridLevels[i] > ask && orderNumber < 3)
            {
                orderIndex[orderNumber] = i;
                orderNumber++;
            }
        }

        for (int i = InpGridCount - 1; i >= 0; i--)
        {
            bool isHaveOrder = false;
            bool isHavePosition = false;

            string gridName = "GridOrder_" + IntegerToString(i);
            for (int j = OrdersTotal() - 1; j >= 0; j--)
            {
                COrderInfo m_orderInfo;
                if (m_orderInfo.SelectByIndex(j) && m_orderInfo.Symbol() == m_Symbol && m_orderInfo.Magic() == m_MagicNumber)
                {
                    string dsc = m_orderInfo.Comment();
                    if (StringFind(dsc, gridName) != -1)
                    {

                        isHaveOrder = true;
                    }
                }
            }

            for (int j = PositionsTotal() - 1; j >= 0; j--)
            {
                CPositionInfo m_positionInfo;
                if (m_positionInfo.SelectByIndex(j) && m_positionInfo.Symbol() == m_Symbol && m_positionInfo.Magic() == m_MagicNumber)
                {
                    string dsc = m_positionInfo.Comment();
                    if (StringFind(dsc, gridName) != -1)
                    {
                        isHavePosition = true;
                    }
                }
            }
            if (!isHavePosition && !isHaveOrder)
            {
                bool isHaveNumber = false;
                // 如果包含在orderIndex中，则挂单
                for (int j = 0; j < orderNumber; j++)
                {
                    if (orderIndex[j] == i)
                    {
                        isHaveNumber = true;
                    }
                }

                if (isHaveNumber)
                {
                    m_PendingOrders[i] = false;
                }
                else
                {
                    m_PendingOrders[i] = true;
                }
            }
        }

        for (int i = InpGridCount - 1; i >= 0; i--)
        {

            string gridName = "GridOrder_" + IntegerToString(i);
            bool isHaveNumber = false;
            ulong ticket = 0;
            for (int j = OrdersTotal() - 1; j >= 0; j--)
            {
                COrderInfo m_orderInfo;
                if (m_orderInfo.SelectByIndex(j) && m_orderInfo.Symbol() == m_Symbol && m_orderInfo.Magic() == m_MagicNumber)
                {
                    string dsc = m_orderInfo.Comment();
                    if (dsc == gridName)
                    {
                        // 如果包含在orderIndex中，则挂单
                        for (int k = 0; k < orderNumber; k++)
                        {
                            if (orderIndex[k] == i)
                            {
                                isHaveNumber = true;
                            }
                        }
                        if (!isHaveNumber)
                            ticket = m_orderInfo.Ticket();
                    }
                }
            }

            if (!isHaveNumber && ticket != 0)
                m_Trade.OrderDelete(ticket);
        }
    }

    void OnDeinit(const int reason)
    {
        m_Tools.CloseAllPositions(m_MagicNumber);
        m_Tools.DeleteAllOrders(m_MagicNumber);
    }
};

CGrid *g_Strategy;

int OnInit()
{
    if (InpGridCount < 2)
    {
        Alert("网格数量必须大于1!");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (InpUpLimit <= InpDownLimit)
    {
        Alert("上限必须大于下限!");
        return INIT_PARAMETERS_INCORRECT;
    }

    g_Strategy = new CGrid(_Symbol, InpTimeframe, InpBaseMagicNumber);
    return INIT_SUCCEEDED;
}

void OnTick()
{
    g_Strategy.OnTick();
}

void OnDeinit(const int reason)
{
    g_Strategy.OnDeinit(reason);
}