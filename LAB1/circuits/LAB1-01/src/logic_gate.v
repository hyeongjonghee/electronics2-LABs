module logic_gate(input wire a,b, output wire x,y,z);
  assign x = a & b;
  assign y = a | b;
  assign z = a ^ b;
endmodule
