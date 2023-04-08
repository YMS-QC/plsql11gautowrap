CREATE OR REPLACE Package Cux_Test_Api_Pkg Is

  Type t_Line_Record Is Record(
    Header_Id Cux_Test_Line_Table.Header_Id%Type,
    Line_Id   Cux_Test_Line_Table.Line_Id%Type,
    Line_Str  Cux_Test_Line_Table.Line_Str%Type);

  Type t_Head_Record Is Record(
    Header_Id  Cux_Test_Head_Table.Header_Id%Type,
    Header_Str Cux_Test_Head_Table.Header_Str%Type);

  Type t_Line_Tbl Is Table Of t_Line_Record Index By Pls_Integer;

  Type t_Obect Is Record(
    Header   t_Head_Record,
    Line_Tbl t_Line_Tbl);

  Procedure Api(Param_In  In t_Obect,
                Param_Out Out t_Obect);

End Cux_Test_Api_Pkg;
/
CREATE OR REPLACE Package Body Cux_Test_Api_Pkg Is

  Procedure Api(Param_In  In t_Obect,
                Param_Out Out t_Obect) As
  
  Begin
    Param_Out := Param_In;
  
  End;
End Cux_Test_Api_Pkg;
/
