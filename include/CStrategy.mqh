#include<Trade/Trade.mqh>


enum SignalType {
    BuySignal,
    SellSignal,
    NoSignal
};


class CStrategy {
protected:
    string m_Symbol;           // 交易品种
    ENUM_TIMEFRAMES m_Timeframe; // 时间周期
    int m_MagicNumber;         // 魔术号，标记订单
    CTrade m_Trade;            // 交易对象

public:
    // 构造函数
    CStrategy(string _symbol, ENUM_TIMEFRAMES _timeframe, int _magicNumber) {
        m_Symbol = _symbol;
        m_Timeframe = _timeframe;
        m_MagicNumber = _magicNumber;
    }
    ~CStrategy() {};

    // 初始化方法
    virtual bool Initialize() {
        Print("Strategy Initialized: ", m_Symbol);
        return true;
    }

    // 检查信号（虚函数，需子类实现）
    virtual SignalType CheckSignal() {
        Print("CheckSignal() not implemented!");
        return NoSignal;
    }

    // 风险管理（虚函数，子类可自定义实现）
    virtual bool RiskManagement() {
        // 默认通过风险管理
        return true;
    }

    // 执行交易逻辑
    virtual void ExecuteTrade() {
    
    }

    virtual void ExitTrade() {
    }

    // Tick事件入口
    void OnTick() {
        ExecuteTrade();
    }

    void OnDeinit(const int reason) {
        ExitTrade();
    }


};
