#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
#include "include/Draw.mqh"

input group "----->美日参数";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // 周期
input int InpBaseMagicNumber = 5424524;         // 基础魔术号
input double InpLotSize = 0.01;                 // 交易手数
input double InpUpLimit = 85282.0;              // 上限
input double InpDownLimit = 77959.0;            // 下限
input int InpGridCount = 30;                    // 网格数量

class CGrid : public CStrategy
{
private:
    CTools *tools;
    CDraw draw;
    double gridLevels[];  // 存储所有网格价格层级
    bool pendingOrders[]; // 挂单状态标志
    int digits;           // 品种小数位数
    double point;         // 品种点值

    void InitGridLevels()
    {
        double step = (InpUpLimit - InpDownLimit) / (InpGridCount - 1);
        ArrayResize(gridLevels, InpGridCount);
        ArrayResize(pendingOrders, InpGridCount);
        for (int i = 0; i < InpGridCount; i++)
        {
            gridLevels[i] = InpUpLimit - step * i;
            pendingOrders[i] = true;
        }
        // 初始化精度参数
        digits = (int)SymbolInfoInteger(m_Symbol, SYMBOL_DIGITS);
        point = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
    }

    double GetTakeProfitPrice(int level)
    {
        if (level < InpGridCount - 1)
            return gridLevels[level + 1];
        return gridLevels[level] - (gridLevels[0] - gridLevels[1]);
    }

public:
    CGrid(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber)
        : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        tools = new CTools(symbol, &m_Trade);
        InitGridLevels();
    }

    ~CGrid()
    {
        delete tools;
    }

    void OnTick() override
    {

        if (!tools.IsNewBar(PERIOD_M1))
            return;

        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);

        // 第一部分：检查满足条件的网格挂单，执行SellLimit挂单
        for (int i = InpGridCount - 1; i >= 0; i--)
        {
            if (gridLevels[i] > ask && !pendingOrders[i])
            {
                double tpPrice = GetTakeProfitPrice(i);
                double normPrice = NormalizeDouble(gridLevels[i], digits);
                double normTP = NormalizeDouble(tpPrice, digits);
                if (m_Trade.SellLimit(InpLotSize, normPrice, m_Symbol, 0, normTP, ORDER_TIME_GTC, 0, "GridOrder_" + IntegerToString(i)))
                {
                    pendingOrders[i] = true;
                    Print("SellLimit挂单成功 价格:", gridLevels[i], " TP:", tpPrice);
                }
                else
                {
                    Print("挂单失败! 错误:", GetLastError());
                }
            }
        }

        if (!tools.IsNewBar(PERIOD_M1))
            return;

        // 第二部分：合并允许挂单判断、挂单状态更新及不允许挂单订单删除
        int allowedCount = 0;
        int totalOrders = OrdersTotal();
        int totalPositions = PositionsTotal();
        for (int i = InpGridCount - 1; i >= 0; i--)
        {
            // 判断是否允许挂单（最多允许3个挂单，且当前网格价格需大于ask）
            bool allowed = false;
            if (gridLevels[i] > ask && allowedCount < 3)
            {
                allowed = true;
                allowedCount++;
            }

            bool haveOrder = false;
            bool havePosition = false;
            ulong ticket = 0;
            string gridTag = "GridOrder_" + IntegerToString(i);

            // 遍历订单列表查找当前网格的挂单
            for (int j = totalOrders - 1; j >= 0; j--)
            {
                COrderInfo orderInfo;
                if (orderInfo.SelectByIndex(j) && orderInfo.Symbol() == m_Symbol && orderInfo.Magic() == m_MagicNumber)
                {
                    string comment = orderInfo.Comment();
                    if (StringFind(comment, gridTag) != -1)
                    {
                        haveOrder = true;
                        // 如果不允许挂单且发现订单评论完全匹配，则记录ticket以便删除
                        if (!allowed && comment == gridTag)
                            ticket = orderInfo.Ticket();
                    }
                }
            }

            // 遍历仓位列表查找当前网格的持仓
            for (int j = totalPositions - 1; j >= 0; j--)
            {
                CPositionInfo posInfo;
                if (posInfo.SelectByIndex(j) && posInfo.Symbol() == m_Symbol && posInfo.Magic() == m_MagicNumber)
                {
                    if (StringFind(posInfo.Comment(), gridTag) != -1)
                    {
                        havePosition = true;
                        break;
                    }
                }
            }

            // 当既没有订单也没有持仓时，根据是否允许挂单更新pendingOrders标志
            if (!haveOrder && !havePosition)
                pendingOrders[i] = allowed ? false : true;

            // 对不允许挂单的网格删除订单
            if (!allowed && ticket != 0)
                m_Trade.OrderDelete(ticket);
        }
    }

    void OnDeinit(const int reason)
    {
        tools.CloseAllPositions(m_MagicNumber);
        tools.DeleteAllOrders(m_MagicNumber);
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
