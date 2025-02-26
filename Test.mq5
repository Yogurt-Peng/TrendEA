#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
#include "include/Draw.mqh"
// 基本参数  US500 DAY 最佳
input group "----->欧美货币";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 564814;               // 基础魔术号
input double InpAccountPercentage = 0.1;
input group "----->高点低点";
input int InpDepth = 10;   // 深度
input int InpDevotion = 5; // 偏离
input int InpBackStep = 2;
input int InpDeleteOrlderTime = 10; // 删除订单时间（H）
input group "----->止盈止损";
input int InpStopLoss = 100;   // 止损
input int InpTakeProfit = 100; // 止盈
input group "----->跟踪止损";
input int InpTrailingStopPips = 20;     // 跟踪止损
input int TriggerTrailingStopPips = 10; // 触发跟踪止损

class CStrateging : public CStrategy
{
private:
  CTools *m_Tools;

public:
  CALMA *m_ALMA;
  CMA *m_EMAFast;
  CMA *m_EMASlow;

public:
  CStrateging(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
  {
    m_Zigzag = CZigzag(symbol, timeFrame, InpDepth, InpDevotion, InpBackStep);
    m_Tools = new CTools(symbol, &m_Trade);
    m_Trade.SetExpertMagicNumber(m_MagicNumber);
  };
  ~CStrateging() {};

  // 重写Initialize函数
  bool Initialize() override
  {
    // 初始化EMAFast指标
    if (!m_EMAFast.Initialize())
    {
      Print("Failed to initialize EMAFast indicator for ", m_Symbol);
      return false;
    }
    // 初始化EMASlow指标

    return true;
  };

  // 自定义信号逻辑
  SignalType TradeSignal() override
  {
    // 多头排列且满足均线发散条件

    return NoSignal;
  };

  void ExecuteTrade() override
  {

    if (!m_Tools.IsNewBar(m_Timeframe))
      return;
  }

  void OnDeinit(const int reason) {

  };
};
CStrateging *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{

  g_Strategy = new CStrateging(_Symbol, InpTimeframe, InpBaseMagicNumber);
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
