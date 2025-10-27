//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

input ENUM_TIMEFRAMES BbTimeframe = PERIOD_CURRENT; //Timeframe
input int BbPeriod = 20; //Period
input double BbDeviation = 2.0; //Deviation
input ENUM_APPLIED_PRICE BbAppPrice = PRICE_CLOSE; //Applied Price

input bool IsMaFilter = true;
input ENUM_TIMEFRAMES MaTimeframe = PERIOD_CURRENT;
input int MaPeriod = 200;
input ENUM_MA_METHOD MaMethod = MODE_SMA;
input ENUM_APPLIED_PRICE MaAppPrice = PRICE_CLOSE;

input double Lots = 0.1;
input int TpPoints = 100;
input int SlPoints = 100;

input int TslTriggerPoints = 50;
input int TslPoints = 50;
input int TslStepPoints = 5;

input int Magic = 1;
input string Commentary = "order comment";

int handleBb, handleMa;
datetime timestamp;

CTrade trade;

ulong posBuy, posSell;

int OnInit() {

    trade.SetExpertMagicNumber(Magic);
    trade.SetTypeFillingBySymbol(_Symbol);

    static bool isInit = false;
    if(!isInit) {
        isInit = true;

        for(int i = PositionsTotal()-1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);

            if(PositionSelectByTicket(ticket)) {
                if(PositionGetInteger(POSITION_MAGIC) != Magic) continue;
                if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

                Print(__FUNCTION__" > Found open pos #",ticket,"...");
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                if(posType == POSITION_TYPE_BUY) {
                    posBuy = ticket;
                } else if(posType == POSITION_TYPE_SELL) {
                    posSell = ticket;
                }
            }
        }
    }

    timestamp = iTime(_Symbol,BbTimeframe,0);

    handleBb = iBands(_Symbol,BbTimeframe,BbPeriod,0,BbDeviation,BbAppPrice);
    handleMa = iMA(_Symbol,MaTimeframe,MaPeriod,0,MaMethod,MaAppPrice);

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
    checkTrade(posBuy);
    checkTrade(posSell);

    datetime time = iTime(_Symbol,BbTimeframe,0);
    if(timestamp != time) {
        timestamp = time;

        double bbUpper[], bbLower[];
        ArraySetAsSeries(bbUpper,true);
        ArraySetAsSeries(bbLower,true);
        CopyBuffer(handleBb,UPPER_BAND,1,2,bbUpper);
        CopyBuffer(handleBb,LOWER_BAND,1,2,bbLower);

        double ma[];
        CopyBuffer(handleMa,0,0,1,ma);

        double close1 = iClose(_Symbol,BbTimeframe,1);
        double close2 = iClose(_Symbol,BbTimeframe,2);

        double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

        if(close1 > bbUpper[0] && close2 < bbUpper[1]) {
            Print(__FUNCTION__," > Long breakout...");

            if(!IsMaFilter || bid < ma[0]) {
                if(posSell <= 0) {
                    posSell = executeSell();
                }
            }
        } else if(close1 < bbLower[0] && close2 > bbLower[1]) {
            Print(__FUNCTION__," > Short breakout...");

            if(!IsMaFilter || bid > ma[0]) {
                if(posBuy <= 0) {
                    posBuy = executeBuy();
                }
            }
        }

        Comment("\nBB Upper [0]: ",DoubleToString(bbUpper[0],_Digits),
                "\nBB Upper [1]: ",DoubleToString(bbUpper[1],_Digits),
                "\nBB Lower [0]: ",DoubleToString(bbLower[0],_Digits),
                "\nBB Lower [1]: ",DoubleToString(bbLower[1],_Digits),
                "\nMa: ",DoubleToString(ma[0],_Digits),
                "\nLast Close: ",DoubleToString(close1,_Digits),
                "\nPrevious Close: ",DoubleToString(close2,_Digits),
                "\nCurrent Time: ",time,
                "\n\nBuy Position: ",posBuy,
                "\nSell Position: ",posSell);
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong executeBuy() {
    double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

    double tp = ask + TpPoints * _Point;
    tp = NormalizeDouble(tp,_Digits);

    double sl = ask - SlPoints * _Point;
    sl = NormalizeDouble(sl,_Digits);

    trade.Buy(Lots,_Symbol,0,sl,tp,Commentary);

    return trade.ResultOrder();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong executeSell() {
    double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

    double tp = bid - TpPoints * _Point;
    tp = NormalizeDouble(tp,_Digits);

    double sl = bid + SlPoints * _Point;
    sl = NormalizeDouble(sl,_Digits);

    trade.Sell(Lots,_Symbol,0,sl,tp,Commentary);

    return trade.ResultOrder();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkTrade(ulong &ticket) {
    if(ticket > 0) {
        if(PositionSelectByTicket(ticket)) {

            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double posEntry = PositionGetDouble(POSITION_PRICE_OPEN);
            double posSl = PositionGetDouble(POSITION_SL);
            double posTp = PositionGetDouble(POSITION_TP);

            double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

            if(posType == POSITION_TYPE_BUY) {
                if(bid > posEntry + TslTriggerPoints * _Point) {
                    double sl = bid - TslPoints * _Point;
                    sl = NormalizeDouble(sl,_Digits);

                    if(sl > posSl + TslStepPoints * _Point) {
                        if(trade.PositionModify(ticket,sl,posTp)) {
                            Print(__FUNCTION__," > Position #",ticket," was modified by tsl...");
                        }
                    }
                }
            } else if(posType == POSITION_TYPE_SELL) {
                if(ask < posEntry - TslTriggerPoints * _Point) {
                    double sl = ask + TslPoints * _Point;
                    sl = NormalizeDouble(sl,_Digits);

                    if(sl < posSl - TslStepPoints * _Point || posSl == 0) {
                        if(trade.PositionModify(ticket,sl,posTp)) {
                            Print(__FUNCTION__," > Position #",ticket," was modified by tsl...");
                        }
                    }
                }
            }
        } else {
            Print(__FUNCTION__," > Pos #",ticket," is closed...");
            ticket = 0;
        }
    }
}
//+------------------------------------------------------------------+
