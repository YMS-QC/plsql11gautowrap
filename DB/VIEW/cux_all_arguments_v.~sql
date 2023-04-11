create or replace view cux_all_arguments_v as
Select x."OWNER",
       x."OBJECT_NAME",
       x."PACKAGE_NAME",
       x."OBJECT_ID",
       x."OVERLOAD",
       x."SUBPROGRAM_ID",
       x."ARGUMENT_NAME",
       x."POSITION",
       x."SEQUENCE",
       Nvl((Select Nvl(Max(s.Sequence),
                      0)
             From All_Arguments s
            Where s.Data_Level = x.Data_Level - 1
              And s.Sequence < x.Sequence
              And s.Object_Id = x.Object_Id
              And s.Object_Name = x.Object_Name
              And s.Package_Name = x.Package_Name),
           0) As Parent_Sequence,
       x."DATA_LEVEL",
       x."DATA_TYPE",
       x."DEFAULTED",
       x."DEFAULT_VALUE",
       x."DEFAULT_LENGTH",
       x."IN_OUT",
       x."DATA_LENGTH",
       x."DATA_PRECISION",
       x."DATA_SCALE",
       x."RADIX",
       x."CHARACTER_SET_NAME",
       x."TYPE_OWNER",
       x."TYPE_NAME",
       x."TYPE_SUBNAME",
       x."TYPE_LINK",
       x."PLS_TYPE",
       x."CHAR_LENGTH",
       x."CHAR_USED",
       Case When x.data_type In ('PL/SQL TABLE','PL/SQL RECORD') Then
       Type_Name || '$' || Type_Subname  Else Null End As Orig_Typename,
       
       Case When x.data_type In ('PL/SQL TABLE','PL/SQL RECORD') Then
       First_Value(Substr(Type_Name || '$' || Type_Subname,
                          0,
                          (30 -
                          Lengthb('$' || Object_Id || '_' || Subprogram_Id || '_' ||
                                   Sequence))) ||
                   ('$' || Object_Id || '_' || Subprogram_Id || '_' ||
                    Sequence)) Over(Partition By Object_Id, Package_Name, Object_Name, Type_Name || '$' || Type_Subname Order By Sequence Desc) Else Null End  As Wrapped_Objname

  From All_Arguments x;
