//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

input double Lots = 0.1;

input ENUM_TIMEFRAMES DonchianChannelTimeframe = PERIOD_CURRENT;
input int DonchianChannelCandles = 20;

input int Magic = 1;

int handle;
ulong posTicket;
CTrade trade;

int OnInit() {

    trade.SetExpertMagicNumber(Magic);

    handle = iCustom(_Symbol,DonchianChannelTimeframe,"Donchian_Channel.ex5",DonchianChannelCandles);


    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {


}

void OnTick() {

    double dcUpper[], dcLower[];
    CopyBuffer(handle,0,1,1,dcUpper);
    CopyBuffer(handle,1,1,1,dcLower);

    double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

    if(bid > dcUpper[0]) {
        Print(__FUNCTION__," > New buy signal...");

        if(posTicket > 0 && PositionSelectByTicket(posTicket)) {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(posType == POSITION_TYPE_SELL) {
                Print(__FUNCTION__," > Pos #",posTicket," will be closed...");
                trade.PositionClose(posTicket);

                if(trade.ResultRetcode() == TRADE_RETCODE_DONE) {
                    posTicket = 0;
                }
            }
        } else {
            Print(__FUNCTION__," > Pos #",posTicket," could not be selected...");
            posTicket = 0;
        }

        if(posTicket <= 0) {
            trade.Buy(Lots,_Symbol,0,0,0,"This ia buy");

            posTicket = trade.ResultOrder();
        }

    } else if(bid < dcLower[0]) {
        Print(__FUNCTION__," > New sell signal...");

        if(posTicket > 0 && PositionSelectByTicket(posTicket)) {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(posType == POSITION_TYPE_BUY) {
                Print(__FUNCTION__," > Pos #",posTicket," will be closed...");
                trade.PositionClose(posTicket);

                if(trade.ResultRetcode() == TRADE_RETCODE_DONE) {
                    posTicket = 0;
                }
            }
        } else {
            Print(__FUNCTION__," > Pos #",posTicket," could not be selected...");
            posTicket = 0;
        }

        if(posTicket <= 0) {
            trade.Sell(Lots,_Symbol,0,0,0,"This is the comment");

            posTicket = trade.ResultOrder();
        }

    }

    Comment("Pos #",posTicket,
            "\n",dcUpper[0], " ", dcLower[0]);
}
//+------------------------------------------------------------------+
