Create Or Replace Function Get_Argument_Default_Val(p_Object_Id     In Number,
                                                    p_Subprogram_Id In Number,
                                                    p_Sequence      In Number)
  Return Varchar2 Is
  l_Default_Value Varchar2(1000);
Begin

  Select Default_Value
    Into l_Default_Value
    From All_Arguments Al
   Where Al.Object_Id = p_Object_Id
     And Al.Subprogram_Id = p_Subprogram_Id
     And Al.Sequence = p_Sequence;

  Return l_Default_Value;
Exception
  When Others Then
    Return Sqlerrm;
  
End;
/
