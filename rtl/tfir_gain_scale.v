module tfir_gain_scale #(
    parameter IN_W = 40,
    parameter OUT_W = 16,
    parameter FRAC_W = 14
)(
    input  signed [IN_W-1:0] in_data,
    input         [1:0]      gain_sel,
    output reg signed [OUT_W-1:0] out_data
);

    reg signed [IN_W:0] scaled_value;
    reg signed [IN_W:0] normalized_value;

    always @* begin
        case (gain_sel)
            2'd0: scaled_value = in_data <<< 1;
            2'd1: scaled_value = in_data;
            2'd2: scaled_value = in_data >>> 1;
            default: scaled_value = in_data >>> 2;
        endcase

        normalized_value = scaled_value >>> FRAC_W;
        out_data = normalized_value[OUT_W-1:0];
    end

endmodule