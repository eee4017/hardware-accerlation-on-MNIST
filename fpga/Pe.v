module Main(
    input clk,
    input reset,
    
    input rx,
    output tx,

    output [4:0] state_led,
    output [3:0] ANSWER,

    output reg number_valid 
); 
    parameter IntSize   =   8;
    parameter CoreSize  =  25;
    parameter PicSize1  = 784;
    parameter PicSize2  = 196;
    parameter PicSize3  =  49;

    //  RS232 Module    
    wire [7:0] rx_data;
    wire tx_busy,rx_rdy;
    reg [7:0] tx_data;
    reg tx_en;
    wire clk_9600;
    rs232 RS232(
        .clk(clk),
        .rst(reset),
        .rx(rx),
        .tx(tx),

        .txdata(tx_data),
        .txdata_en(tx_en),
        .tx_busy(tx_busy),
        
        .rxdata(rx_data),
        .rxdata_rdy(rx_rdy),

        .clk_9600(clk_9600)
    );
    
    //  FileInfo Module

    reg [2:0] stage , n_stage ;
    reg [4:0] state , n_state ;
    reg [20:0] cal_cnt , n_cal_cnt ;

    assign state_led = state;
    
    //parameter for state : 
    parameter [4:0] IDLE              = 5'd0;
    parameter [4:0] STAGE1            = 5'd1;
    parameter [4:0] IO                = 5'd2;
    parameter [4:0] SEND_HEAD         = 5'd3;
    parameter [4:0] SEND_FILE_INDEX   = 5'd4;
    parameter [4:0] READ_GET_BYTE     = 5'd5;
    parameter [4:0] WRITE_SEND_BYTE   = 5'd6;
    parameter [4:0] WAIT_FOR_UPLOAD   = 5'd7;
    parameter [4:0] CAL_CONV          = 5'd8;
    parameter [4:0] CAL_MAXPOOL       = 5'd9;
    parameter [4:0] STAGE1_CHECK_END = 5'd10;
    parameter [4:0] STAGE2           = 5'd11;
    parameter [4:0] STAGE2_CHECK_END = 5'd12;
    parameter [4:0] STAGE3           = 5'd13;
    parameter [4:0] STAGE3_CHECK_END = 5'd14;
    parameter [4:0] FIN              = 5'd15;
    parameter [4:0] CAL_ADD          = 5'd16;
    parameter [4:0] CAL_MULTI        = 5'd17;
    parameter [4:0] FIND_MAX         = 5'd18;
    parameter [4:0] IO_FIN           = 5'd19;
    
    //TODO IO_CLK SHANGE
    
    reg [IntSize-1:0] n_max , max;
    reg [3:0] n_ans , ans;
    assign ANSWER = ans;
    reg [5:0] upload_tmp_state  ,   n_upload_tmp_state;
    reg [15:0] bufferpos         ,   n_bufferpos       ;
   
    reg [15:0] FileIndex    ,   n_FileIndex    ;
    reg [4:0] Temp_state    ,   n_Temp_state   ;
    reg [20:0] Tcnter       ,   n_Tcnter       ;
    
    reg [1:0]  ReadWrite    ,   n_ReadWrite    ;
    parameter READ = 2'b10;
    parameter WRITE = 2'b01;


    wire [15:0] file_size,memory_start,memory_end;
    file_info FI(FileIndex,memory_start,memory_end);

    //TOD ram memory 

    reg [IntSize*2600-1:0] memory ;
    reg [IntSize*2600-1:0] n_memory ;

    // Set memory for var
    // give the right var  //ref : http://goo.gl/5NgdCK
    //TODO: assign those val !!!!
    //Stage 1 
    wire [IntSize*PicSize1-1:0] unprocessedPicture      ; 
    wire [IntSize*25-1 :0] Core1                        ;
    wire [IntSize*PicSize1-1:0] Conv1Bias               ;
    wire [IntSize*PicSize1-1:0] PictureAfterConv1        ;
    wire [IntSize*196-1:0] PictureAfterMaxpool1          ;
    
    assign unprocessedPicture = memory[6271:0];            // Read only
    assign Core1 = memory[6471:6272];                      // Read only
    assign PictureAfterConv1 = memory[19015:12744];         // Write / Read 
    assign PictureAfterMaxpool1 = memory[20583:19016];      // Write only
   
    //  FileInfo Module
    //reg [15:0] file,n_file;
    //conv module 
    //data , dPstate , core ,out

    wire [IntSize-1:0] out_c28;
    
    conv28x28 c28(.data(unprocessedPicture),.dPstate(cal_cnt),.core(Core1),.out(out_c28));
//maxpool module
    wire [IntSize-1:0] out_m14;
    
    maxpool14x14 m14(.data(PictureAfterConv1),.maxPoolState(cal_cnt),.out(out_m14))  ;

    wire FSM_clk;
    assign FSM_clk = ( state == IO || state == SEND_HEAD || state == SEND_FILE_INDEX || state == READ_GET_BYTE || state == WRITE_SEND_BYTE || state == WAIT_FOR_UPLOAD  ) ? clk_9600 : clk;
always @(posedge FSM_clk or posedge reset ) begin
    if(reset)begin
        state = IDLE;
    end
    // TODO ??��?�裡??��?�數弄好
    else begin
    
        state       =   n_state;
        Tcnter      =   n_Tcnter;
        stage       =   n_stage ; 
        cal_cnt     =   n_cal_cnt;
        upload_tmp_state = n_upload_tmp_state;
        bufferpos   =   n_bufferpos;
        max         =   n_max;
        ans         =   n_ans;
        memory      =   n_memory;
        //file        =   n_file;
        FileIndex   = n_FileIndex;
        ReadWrite =  n_ReadWrite;
        Temp_state = n_Temp_state;
    end
end


always @* begin
    n_Temp_state = Temp_state;
    n_ReadWrite = ReadWrite;
    n_FileIndex = FileIndex;
    n_ans       = ans       ;
    n_max       = max       ;
    n_state     = state     ;
    n_Tcnter    = Tcnter    ;
    n_stage     = stage     ;
    n_cal_cnt   = cal_cnt   ;
    n_state     = state     ;
    n_Tcnter    = Tcnter    ;
    n_stage     = stage     ;
    n_memory    = memory    ;
    
    // IO varibles default values
    tx_en = 0;
    tx_data = 0;
    n_upload_tmp_state = upload_tmp_state;
    n_bufferpos = bufferpos;
    
    number_valid = 0;

    case(state)
        IDLE:begin
            n_Tcnter = 0;
            n_state = STAGE1; 
        end
        
        IO:begin
            n_state = SEND_HEAD;
        end
        
        SEND_HEAD:begin
            if(!tx_busy)begin
                tx_data = (ReadWrite == READ) ? 8'd82 : 8'd87; // R : W
                n_state = WAIT_FOR_UPLOAD;
                n_upload_tmp_state = SEND_FILE_INDEX;
                n_bufferpos = 0;
            end
        end

        SEND_FILE_INDEX:begin
            if(!tx_busy && bufferpos < 2)begin
                    tx_data = FileIndex[bufferpos*8 +: 8];
                    n_bufferpos = bufferpos + 1;
                    n_state = WAIT_FOR_UPLOAD;
                    n_upload_tmp_state = SEND_FILE_INDEX;
            end else if(bufferpos >= 2)begin
                n_state = (ReadWrite == READ) ? READ_GET_BYTE : WRITE_SEND_BYTE;    
                n_bufferpos = memory_start;
            end
        end

        READ_GET_BYTE:begin
            if(rx_rdy && bufferpos <= memory_end)begin
                n_memory[(bufferpos)<<3 +: 8] = rx_data;
                n_bufferpos = bufferpos + 1;
            end else if (bufferpos > memory_end) begin
                n_state = IO_FIN;
            end
        end
        
        WRITE_SEND_BYTE:begin
            if(!tx_busy && bufferpos <= memory_end)begin
                tx_data = memory[(bufferpos)<<3 +: 8];
                n_bufferpos = bufferpos + 1;
                n_state = WAIT_FOR_UPLOAD;
                n_upload_tmp_state = WRITE_SEND_BYTE;
            end else if(bufferpos > memory_end)begin
                n_state = IO_FIN;    
            end
        end
        
        WAIT_FOR_UPLOAD:begin
            tx_en = 1;
            if(!tx_busy)begin
                n_state = upload_tmp_state;
            end
        end

        IO_FIN:begin
            n_state = Temp_state;
        end

        CAL_CONV:begin
            //28*28 CONV
            if(stage == 1) begin
                if(cal_cnt<784)begin
                    n_cal_cnt = cal_cnt + 1; 
                    n_memory[(1593+cal_cnt)<<3 +: 8] = out_c28;
                end
                else begin
                    n_state = STAGE1_CHECK_END;
                end
            end
        end
        CAL_MAXPOOL:begin
            //28*28 MAXPOOL
            if(stage == 1) begin
                if(cal_cnt<784)begin
                    n_cal_cnt = cal_cnt + 1; 
                    n_memory[(2377+cal_cnt)<<3 +: 8] = out_m14;
                end
                else begin
                    n_state = STAGE1_CHECK_END;
                end
            end
        end

        STAGE1:begin
            n_stage     = 1 ;
            n_cal_cnt   = 0 ;
            if(Tcnter==0)begin
                //load unprocessed picture 

                n_Tcnter    = Tcnter + 1    ;
                n_FileIndex = 0             ;
                n_ReadWrite = 2'b10         ;
                n_Temp_state= STAGE1        ;
                n_state     = IO            ;
            end
            else if(0<Tcnter && Tcnter <=32)begin
                //load Cores
                
                //n_Tcnter
                n_FileIndex = Tcnter        ; // 1 ~ 32
                n_ReadWrite = 2'b10         ;
                n_Temp_state= CAL_CONV      ;
                n_state     = IO            ;
            end
            else if(32<Tcnter && Tcnter <=96)begin
                n_Tcnter = Tcnter + 1 ;
            end
            //MAXPOOL
            else if(96<Tcnter && Tcnter <= 128)begin
                //load Picture After Conv1 and calcluate maxpool
                
                //n_Tcnter
                n_FileIndex  = Tcnter - 32   ;  //65~96 
                n_ReadWrite  = 2'b10         ;
                n_Temp_state = CAL_MAXPOOL   ;
                n_state      = IO            ;
            end
        end

        STAGE1_CHECK_END:begin
            //CONV SAVE
            if(0<Tcnter && Tcnter <=32)begin
                //save PictureAfterConv1

                n_Tcnter    = Tcnter + 1    ;
                n_FileIndex = 64+Tcnter     ; // save at 65~96 
                n_ReadWrite = 2'b01         ;
                n_Temp_state= STAGE1        ;
                n_state     = IO            ;
            end
            //BIAS SAVE
            else if(32<Tcnter && Tcnter <= 96)begin
                //save PictureAfterConv1

                n_Tcnter    = Tcnter + 1    ;
                n_FileIndex  = 49+Tcnter[20:1]; // save at 65 ~ 96 
                n_ReadWrite  = 2'b01         ;
                n_Temp_state = STAGE1        ;
                n_state      = IO            ; 
            end
            //MAXPOOL SAVE 
            else if(96<Tcnter && Tcnter < 128)begin
                //save PictureAfterMaxpool1

                n_Tcnter    = Tcnter + 1     ; // save at 97 ~ 127 
                n_FileIndex  = Tcnter        ;
                n_ReadWrite  = 2'b01         ;
                n_Temp_state = STAGE1        ;
                n_state      = IO            ;     
            end
            //MAXPOOL SAVE & END
            else if(Tcnter == 128)begin
                //save PictureAfterMaxpool1 and goto STAGE2

                n_Tcnter    = 0    ;           //finish
                n_FileIndex  = Tcnter        ; // save at 128
                n_ReadWrite  = 2'b01         ;
                n_Temp_state = FIN        ;
                n_state      = IO            ;    
            end
        end

        FIN:begin
            number_valid = 1;
        end
    endcase
end
endmodule 