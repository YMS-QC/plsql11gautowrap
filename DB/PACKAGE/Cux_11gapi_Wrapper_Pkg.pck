CREATE OR REPLACE Package Cux_11gapi_Wrapper_Pkg Is

  Procedure Get_Wrapobj_Ddl
  
    /*
    @p_Package_Name 包名
    @p_Object_Name  存储过程名(借用 all_arguments视图的列名)
    
    */
  (p_Package_Name In Varchar2,
   p_Object_Name  In Varchar2,
   p_Parent_Seq   In Pls_Integer Default Null,
   p_Ddl_Clob     Out Clob);

  Procedure Get_Wrappck_Spc_Ddl(p_Package_Name In Varchar2,
                                p_Object_Name  In Varchar2);

  Procedure Get_Wrappck_Bdy_Ddl(p_Package_Name In Varchar2,
                                p_Object_Name  In Varchar2);

End Cux_11gapi_Wrapper_Pkg;
/
CREATE OR REPLACE Package Body Cux_11gapi_Wrapper_Pkg Is

  g_Output_Mode Number := 0; --DBMS_OUTPUT.PUT_LINE();  
  g_Output_Clob Clob;

  Procedure Put(Str In Varchar2) Is
  
  Begin
  
    If g_Output_Mode = 0 Then
    
      Dbms_Output.Put(Str);
    
    End If;
  
    --Dbms_LOB.append(g_output_clob,TO_CLOB(str));
  
    g_Output_Clob := g_Output_Clob || Str;
  End;

  Procedure Put_Line(Str Varchar2) Is
  
  Begin
    If g_Output_Mode = 0 Then
    
      Dbms_Output.Put_Line(Str);
    
    End If;
  
    g_Output_Clob := g_Output_Clob || Str || Chr(10);
  End;

  Procedure Get_Wrapobj_Ddl
  
    /*
    @p_Package_Name 包名
    @p_Object_Name  存储过程名(借用 all_arguments视图的列名)
    
    */
  (p_Package_Name In Varchar2,
   p_Object_Name  In Varchar2,
   p_Parent_Seq   In Pls_Integer Default Null,
   p_Ddl_Clob     Out Clob)
  
   Is
  
  Begin
  
    If p_Package_Name Is Null Or p_Object_Name Is Null Then
      Null; --should return error
    
    End If;
  
    --v 0.1 try to use dbms_outpout to produce wrap object of a package.procedure 
  
    --step 01 get all PL/SQL RECORD type argument and PL/SQL 
  
    For Rec In (Select *
                  From Cux_All_Arguments_v v
                 Where 1 = 1
                   And v.Package_Name = Upper(p_Package_Name)
                   And v.Object_Name = Upper(p_Object_Name)
                   And (v.Sequence = p_Parent_Seq Or p_Parent_Seq Is Null)
                   And v.Data_Type In ('PL/SQL TABLE', 'PL/SQL RECORD')
                 Order By Sequence Desc) Loop
    
      /*
        todo 设计一张表，记录 package_name + object_name 对应的所有的包装type的信息?
      */
    
      If Rec.Data_Type = 'PL/SQL TABLE' Then
      
        Put_Line('CREATE OR REPLACE TYPE ' || Rec.Wrapped_Objname || ' ' ||
                 ' FORCE AS TABLE OF ');
      
        For Rec_Sub In (Select *
                          From Cux_All_Arguments_v v
                         Where v.Parent_Sequence = Rec.Sequence
                           And v.Object_Id = Rec.Object_Id
                           And v.Package_Name = Rec.Package_Name
                           And v.Object_Name = Rec.Object_Name
                         Order By Sequence Asc) Loop
          If Rec_Sub.Data_Type = 'PL/SQL RECORD' Then
            Put_Line(Rec_Sub.Wrapped_Objname);
          Else
            Put_Line(Rec_Sub.Argument_Name || '  ' || Rec_Sub.Data_Type || '');
          End If;
        
          Put_Line(';');
        End Loop;
        Put_Line('/');
      End If;
    
      If Rec.Data_Type = 'PL/SQL RECORD' Then
      
        Put_Line('CREATE OR REPLACE TYPE ' || Rec.Wrapped_Objname ||
                 ' FORCE AS OBJECT( ');
      
        For Rec_Sub In (Select v.*, Max(Sequence) Over() As Max_Seq
                          From Cux_All_Arguments_v v
                         Where v.Parent_Sequence = Rec.Sequence
                           And v.Object_Id = Rec.Object_Id
                           And v.Package_Name = Rec.Package_Name
                           And v.Object_Name = Rec.Object_Name
                         Order By Sequence Asc) Loop
        
          If Rec_Sub.Data_Type <> 'PL/SQL RECORD' And
             Rec_Sub.Data_Type <> 'PL/SQL TABLE' Then
            Put(Rec_Sub.Argument_Name || '  ' || Rec_Sub.Data_Type || '(' ||
                Rec_Sub.Data_Length || ')');
          
          Else
          
            Put(Rec_Sub.Argument_Name || ' ' || Rec_Sub.Wrapped_Objname || '  ');
          End If;
        
          If Rec_Sub.Sequence < Rec_Sub.Max_Seq Then
            Put_Line(',');
          Else
            Put_Line(');');
          End If;
        
        End Loop;
      
        Put_Line('/');
      
      End If;
    
    End Loop;
  
    --把所有顶层参数包裹成为一个对象
  
    For Rec_In In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                     From Cux_All_Arguments_v v
                    Where 1 = 1
                      And v.Package_Name = Upper(p_Package_Name)
                      And v.Object_Name = Upper(p_Object_Name)
                      And (v.Sequence = p_Parent_Seq Or p_Parent_Seq Is Null)
                      And v.In_Out = 'IN'
                      And v.Data_Level = 0
                    Order By Sequence Asc) Loop
    
      ---第一行，输出整体对象的对象头
      If Rec_In.Sequence = 1 Then
      
        Put_Line('CREATE OR REPLACE TYPE ' ||
                 --
                 Substr(Rec_In.Package_Name || '$' || Rec_In.Object_Name,
                        0,
                        30 - Lengthb('$in_' || Rec_In.Object_Id || '_' ||
                                     Rec_In.Subprogram_Id)) || '$in_' ||
                 Rec_In.Object_Id || '_' || Rec_In.Subprogram_Id
                 --
                 || ' FORCE AS OBJECT(');
      
      End If;
    
      ---打印参数
      Put('' || Rec_In.Argument_Name || '  ' || Rec_In.Wrapped_Objname);
      If Rec_In.Sequence <> Rec_In.Max_Seq Then
        --打印逗号
        Put_Line(',');
      Else
        --最后一行打印括号
        Put_Line(');');
      End If;
    
    End Loop;
    Put_Line('/');
    For Rec_Out In (Select v.*, Max(v.Sequence) Over() As Max_Seq,Min(v.Sequence) Over() As min_Seq
                      From Cux_All_Arguments_v v
                     Where 1 = 1
                       And v.Package_Name = Upper(p_Package_Name)
                       And v.Object_Name = Upper(p_Object_Name)
                       And (v.Sequence = p_Parent_Seq Or
                           p_Parent_Seq Is Null)
                       And v.In_Out = 'OUT'
                       And v.Data_Level = 0
                     Order By Sequence Asc) Loop
    
      ---第一行，输出整体对象的对象头
      If Rec_Out.Sequence = Rec_Out.min_Seq Then
      
        Put_Line('CREATE OR REPLACE TYPE ' ||
                 --
                 Substr(Rec_Out.Package_Name || '$' || Rec_Out.Object_Name,
                        0,
                        30 - Lengthb('$out_' || Rec_Out.Object_Id || '_' ||
                                     Rec_Out.Subprogram_Id)) || '$out_' ||
                 Rec_Out.Object_Id || '_' || Rec_Out.Subprogram_Id
                 --
                 || ' FORCE AS OBJECT(');
      
      End If;
    
      ---打印参数
      Put('' || Rec_Out.Argument_Name || '  ' || Rec_Out.Wrapped_Objname);
      If Rec_Out.Sequence < Rec_Out.Max_Seq Then
        --打印逗号
        Put_Line(',');
      Else
        --最后一行打印括号
        Put_Line(');');
      End If;
      
    
    End Loop;
  
    p_Ddl_Clob := g_Output_Clob;
  
  End;

  Procedure Get_Wrappck_Spc_Ddl(p_Package_Name In Varchar2,
                                p_Object_Name  In Varchar2) Is
  
    l_Counter  Pls_Integer := 0;
    l_Countend Pls_Integer := 0;
  Begin
  
    ----------------------------
    --create package special   
  
    For Rec In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                  From Cux_All_Arguments_v v
                 Where 1 = 1
                   And v.Package_Name = Upper(p_Package_Name)
                   And v.Object_Name = Upper(p_Object_Name)
                   And v.Data_Type In ('PL/SQL TABLE', 'PL/SQL RECORD')
                 Order By Sequence Asc) Loop
    
      --第一行，声明包名
      If Rec.Sequence = 1 Then
      
        Put_Line('CREATE OR REPLACE PACKAGE ' ||
                 --
                 Substr(Rec.Package_Name || '$' || Rec.Object_Name,
                        0,
                        30 - Lengthb('$pkg_' || Rec.Object_Id || '_' ||
                                     Rec.Subprogram_Id)) || '$pkg_' ||
                 Rec.Object_Id || '_' || Rec.Subprogram_Id
                 --
                 
                 || ' AS');
      
      End If;
    
      /*
      --对嵌套对象生成函数声明
      first generate transfor function
        if a data argument is 'PL/SQL TABLE' or 'PL/SQL RECORD' 
           then
             if it is a inbind argument we need pltosql_seg function accept warpobj as argument and return orig type
             if it is a outbind argument we need sqltopl_seq function accept orig type as argument and return warppobj
        else then this is a permitive data_type 
      */
      If Rec.In_Out = 'IN' Then
      
        Put('  FUNCTION ' || 'pltosql_' || Rec.Sequence || '(');
        Put_Line('p_' || Rec.Sequence || ' ' || Rec.Wrapped_Objname ||
                 ') return ' || Rec.Type_Name || '.' || Rec.Type_Subname || ';');
      
      Elsif Rec.In_Out = 'OUT' Then
        Put('  FUNCTION ' || 'sqltopl_' || Rec.Sequence || '(');
        Put_Line('p_' || Rec.Sequence || ' ' || Rec.Type_Name || '.' ||
                 Rec.Type_Subname || ') return ' || Rec.Wrapped_Objname || ';');
      Else
        --INOUT? 应该不允许吧
        Null;
      
      End If;
    
      /*
      --在最后一个转换生成结束后，对最顶层包裹对象生成两个函数声明，第一个，按照原来参数名称，第二个，把所有参数合并为一个参数
      
      
      second generate transfor function for top wrapobj
        if a data argument is 'PL/SQL TABLE' or 'PL/SQL RECORD' 
           then
             if it is a inbind argument we need pltosql_seg function accept warpobj as argument and return orig type
             if it is a outbind argument we need sqltopl_seq function accept orig type as argument and return warpobj
        else then this is a permitive data_type 
      */
    
      If Rec.Sequence = Rec.Max_Seq Then
      
        --datalevel=0
        --打印基础的包裹的过程
      
        For Rec_Lvl0 In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                           From Cux_All_Arguments_v v
                          Where 1 = 1
                            And v.Package_Name = Upper(p_Package_Name)
                            And v.Object_Name = Upper(p_Object_Name)
                            And v.Data_Level = 0
                          Order By Sequence Asc) Loop
        
          If Rec_Lvl0.Sequence = 1 Then
            Put_Line('PROCEDURE ' || Rec.Object_Name || '(');
          End If;
        
          Put(' ' || Rec_Lvl0.Argument_Name || ' ' || Rec_Lvl0.In_Out || ' ' ||
              Rec_Lvl0.Wrapped_Objname);
        
          If Rec_Lvl0.Sequence = Rec_Lvl0.Max_Seq Then
            --打印函数结束
            Put_Line(');');
          Else
            --打印逗号；
            Put_Line(',');
          End If;
        End Loop;
      
        --打印in参数，out参数合并的过程
        --init counter
        l_Counter := 1;
      
        Select Count(Distinct(In_Out))
          Into l_Countend
          From Cux_All_Arguments_v v
         Where 1 = 1
           And v.Package_Name = Upper(p_Package_Name)
           And v.Object_Name = Upper(p_Object_Name)
           And v.Data_Level = 0
           And v.In_Out In ('IN', 'OUT');
      
        If Nvl(l_Countend, 0) >= l_Counter Then
        
          For Rec_Bind_Obj In (Select v.*
                                 From Cux_All_Arguments_v v
                                Where 1 = 1
                                  And v.Package_Name = Upper(p_Package_Name)
                                  And v.Object_Name = Upper(p_Object_Name)
                                  And v.Data_Level = 0
                                  And v.In_Out = 'IN'
                                  And Rownum = 1
                               Union All
                               Select v.*
                                 From Cux_All_Arguments_v v
                                Where 1 = 1
                                  And v.Package_Name = Upper(p_Package_Name)
                                  And v.Object_Name = Upper(p_Object_Name)
                                  And v.Data_Level = 0
                                  And v.In_Out = 'OUT'
                                  And Rownum = 1) Loop
          
            -- 首行打印声明
            If l_Counter = 1 Then
              Put_Line('PROCEDURE ' || Rec.Object_Name || '(');
            End If;
          
            If Rec_Bind_Obj.In_Out = 'IN' Then
              Put('P_IN IN ' ||
                  --
                  Substr(Rec.Package_Name || '$' || Rec.Object_Name,
                         0,
                         30 - Lengthb('$in_' || Rec.Object_Id || '_' ||
                                      Rec.Subprogram_Id)) || '$in_' ||
                  Rec.Object_Id || '_' || Rec.Subprogram_Id
                  --
                  
                  );
            End If;
          
            If Rec_Bind_Obj.In_Out = 'OUT' Then
              Put('P_OUT IN ' ||
                  --
                  Substr(Rec.Package_Name || '$' || Rec.Object_Name,
                         0,
                         30 - Lengthb('$out_' || Rec.Object_Id || '_' ||
                                      Rec.Subprogram_Id)) || '$out_' ||
                  Rec.Object_Id || '_' || Rec.Subprogram_Id
                  --
                  
                  );
            End If;
          
            -- 末行打印结束
            If l_Counter = l_Countend Then
              Put_Line(');');
            Else
              Put_Line(',');
            End If;
          
            l_Counter := l_Counter + 1;
          End Loop;
        
        End If;
      
        --打印结尾
        Put_Line('END ' ||
                 --
                 Substr(Rec.Package_Name || '$' || Rec.Object_Name,
                        0,
                        30 - Lengthb('$pkg_' || Rec.Object_Id || '_' ||
                                     Rec.Subprogram_Id)) || '$pkg_' ||
                 Rec.Object_Id || '_' || Rec.Subprogram_Id
                 --
                 || ';'
                 
                 );
      End If;
    
    End Loop;
  
    --create package special end
    -----------------------------
  
  End;

  Procedure Get_Wrappck_Bdy_Ddl(p_Package_Name In Varchar2,
                                p_Object_Name  In Varchar2) Is
  
    l_Counter  Pls_Integer := 0;
    l_Countend Pls_Integer := 0;  
    l_Package_Name Varchar2(30);
  Begin
  
    ----------------------------
    --create package body  
  
    For Rec In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                  From Cux_All_Arguments_v v
                 Where 1 = 1
                   And v.Package_Name = Upper(p_Package_Name)
                   And v.Object_Name = Upper(p_Object_Name)
                   And v.Data_Type In ('PL/SQL TABLE', 'PL/SQL RECORD')
                 Order By Sequence Asc
                --不使用倒序，引用函数时需要加包名前缀
                ) Loop
    
      --第一行，声明包名
      If Rec.Sequence = 1 Then
      
        l_Package_Name := Substr(Rec.Package_Name || '$' || Rec.Object_Name,
                                 0,
                                 30 - Lengthb('$pkg_' || Rec.Object_Id || '_' ||
                                              Rec.Subprogram_Id)) ||
                          '$pkg_' || Rec.Object_Id || '_' ||
                          Rec.Subprogram_Id;
      
        Put_Line('CREATE OR REPLACE PACKAGE BODY ' ||
                 --
                 l_Package_Name
                 --
                 
                 || ' AS');
      
      End If;
    
      /*
      --对嵌套对象生成函数声明
      first generate transfor function
        if a data argument is 'PL/SQL TABLE' or 'PL/SQL RECORD' 
           then
             if it is a inbind argument we need pltosql_seg function accept warpobj as argument and return orig type
             if it is a outbind argument we need sqltopl_seq function accept orig type as argument and return warppobj
        else then this is a permitive data_type 
      */
      If Rec.In_Out = 'IN' Then
      
        Put('  FUNCTION ' || 'pltosql_' || Rec.Sequence || '(');
        Put_Line('p_' || Rec.Sequence || ' ' || Rec.Wrapped_Objname ||
                 ') return ' || Rec.Type_Name || '.' || Rec.Type_Subname ||
                 ' as ');
      
        --定义方式和数据类型有关
        If Rec.Data_Type = 'PL/SQL RECORD' Then
          Put_Line('   r_' || Rec.Sequence || ' ' || Rec.Type_Name || '.' ||
                   Rec.Type_Subname || ';');
        Else
          --PL/SQL TABLE
          Put_Line('   r_' || Rec.Sequence || ' ' || Rec.Type_Name || '.' ||
                   Rec.Type_Subname || ';');
        End If;
      
        Put_Line('  begin'); --BEGIN
      
        --数值交换方式和数据类型有关 由于总体游标，我们按照倒序遍历，一般，深层次的转换已经实现了
        If Rec.Data_Type = 'PL/SQL RECORD' Then
          --单行数据，对子层级的对象遍历赋值，遇到嵌套类型，直接用函数转换。
          For Rec_Sub In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                            From Cux_All_Arguments_v v
                           Where 1 = 1
                             And v.Parent_Sequence = Rec.Sequence
                             And v.Package_Name = Upper(p_Package_Name)
                             And v.Object_Name = Upper(p_Object_Name)
                          
                           Order By Sequence Desc) Loop
          
            If Rec_Sub.Data_Type In ('PL/SQL TABLE', 'PL/SQL RECORD') Then
              Put_Line('    r_' || Rec.Sequence || '.' ||
                       Rec_Sub.Argument_Name || ':=' || l_Package_Name ||
                       '.pltosql_' || Rec_Sub.Sequence || '(' || 'p_' ||
                       Rec.Sequence || '.' || Rec_Sub.Argument_Name || ');');
            
            Else
              Put_Line('   r_' || Rec.Sequence || '.' ||
                       Rec_Sub.Argument_Name || ':=' || 'p_' ||
                       Rec.Sequence || '.' || Rec_Sub.Argument_Name || ';');
            
            End If;
          
          End Loop;
        
        Else
          --
          --PL/SQL TABLE
          --table需要循环赋值
          Put_Line('  if p_' || Rec.Sequence || '.count > 0 then');
          Put_Line('  for i in 1 .. p_' || Rec.Sequence || '.count loop');
          --单行数据，对子层级的对象遍历赋值，遇到嵌套类型，直接用函数转换。
          For Rec_Sub In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                            From Cux_All_Arguments_v v
                           Where 1 = 1
                             And v.Parent_Sequence = Rec.Sequence
                             And v.Package_Name = Upper(p_Package_Name)
                             And v.Object_Name = Upper(p_Object_Name)
                          
                           Order By Sequence Desc) Loop
          
            If Rec_Sub.Data_Type In ('PL/SQL TABLE', 'PL/SQL RECORD') Then
              Put_Line('    r_' || Rec.Sequence || '(i)' ||
                       Rec_Sub.Argument_Name || ':=' || l_Package_Name ||
                       '.pltosql_' || Rec_Sub.Sequence || '(' || 'p_' ||
                       Rec.Sequence || '(i)' || Rec_Sub.Argument_Name || ');');
            
            Else
              Put_Line('   r_' || Rec.Sequence || '(i).' ||
                       Rec_Sub.Argument_Name || ':=' || 'p_' ||
                       Rec.Sequence || '(i).' || Rec_Sub.Argument_Name || ';');
            
            End If;
          
          End Loop;
          Put_Line('  end loop;');
          Put_Line('  end if;');
        End If;
        Put_Line('  return r_' || Rec.Sequence || ';');
        Put_Line('  end;'); --END;
      
        ---------------------------------
      Elsif Rec.In_Out = 'OUT' Then
        Put('  FUNCTION ' || 'sqltopl_' || Rec.Sequence || '(');
        Put_Line('p_' || Rec.Sequence || ' ' || Rec.Type_Name || '.' ||
                 Rec.Type_Subname || ') return ' || Rec.Wrapped_Objname ||
                 ' as ');
      
        --定义方式和数据类型有关
        If Rec.Data_Type = 'PL/SQL RECORD' Then
          Put_Line('   r_' || Rec.Sequence || ' ' || Rec.Wrapped_Objname || ';');
        Else
          --PL/SQL TABLE
          Put_Line('   r_' || Rec.Sequence || ' ' || Rec.Wrapped_Objname ||
                   ' := ' || Rec.Wrapped_Objname || '();');
        End If;
      
        Put_Line('  begin'); --BEGIN
      
        --数值交换方式和数据类型有关 由于总体游标，我们按照倒序遍历，一般，深层次的转换已经实现了
        If Rec.Data_Type = 'PL/SQL RECORD' Then
          --单行数据，对子层级的对象遍历赋值，遇到嵌套类型，直接用函数转换。
          For Rec_Sub In (Select v.*,
                                 Max(v.Sequence) Over() As Max_Seq,
                                 Min(v.Sequence) Over() As Min_Seq
                            From Cux_All_Arguments_v v
                           Where 1 = 1
                             And v.Parent_Sequence = Rec.Sequence
                             And v.Package_Name = Upper(p_Package_Name)
                             And v.Object_Name = Upper(p_Object_Name)
                          
                           Order By Sequence Asc) Loop
            If Rec_Sub.Sequence = Rec_Sub.Min_Seq Then
            
              Put_Line('    r_' || Rec.Sequence || ':=' ||
                       Rec.Wrapped_Objname || '(');
            End If;
          
            If Rec_Sub.Data_Type In ('PL/SQL TABLE', 'PL/SQL RECORD') Then
              Put('        ' || Rec_Sub.Argument_Name || '=>' ||
                  l_Package_Name || '.sqltopl_' || Rec_Sub.Sequence || '(' || 'p_' ||
                  Rec.Sequence || '.' || Rec_Sub.Argument_Name || ')');
            
            Else
              Put('        ' || Rec_Sub.Argument_Name || '=>' || 'p_' ||
                  Rec.Sequence || '.' || Rec_Sub.Argument_Name || '');
            
            End If;
          
            If Rec_Sub.Sequence = Rec_Sub.Max_Seq Then
            
              Put_Line(');');
            Else
              Put_Line(',');
            
            End If;
          
          End Loop;
        
        Else
          --
          --PL/SQL TABLE
          --table需要循环赋值
          Put_Line('  if p_' || Rec.Sequence || '.count > 0 then');
          Put_Line('  for i in 1 .. p_' || Rec.Sequence || '.count loop');
          --单行数据，对子层级的对象遍历赋值，遇到嵌套类型，直接用函数转换。
          For Rec_Sub In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                            From Cux_All_Arguments_v v
                           Where 1 = 1
                             And v.Parent_Sequence = Rec.Sequence
                             And v.Package_Name = Upper(p_Package_Name)
                             And v.Object_Name = Upper(p_Object_Name)
                          
                           Order By Sequence Desc) Loop
          
            If Rec_Sub.Data_Type In ('PL/SQL TABLE', 'PL/SQL RECORD') Then
              Put_Line('    r_' || Rec.Sequence || '(i)' ||
                       Rec_Sub.Argument_Name || ':=' || l_Package_Name ||
                       '.sqltopl_' || Rec_Sub.Sequence || '(' || 'p_' ||
                       Rec.Sequence || '(i)' || Rec_Sub.Argument_Name || ');');
            
            Else
              Put_Line('   r_' || Rec.Sequence || '(i).' ||
                       Rec_Sub.Argument_Name || ':=' || 'p_' ||
                       Rec.Sequence || '(i).' || Rec_Sub.Argument_Name || ';');
            
            End If;
          
          End Loop;
          Put_Line('  end loop;');
          Put_Line('  end if;');
        End If;
        Put_Line('  return r_' || Rec.Sequence || ';');
        Put_Line('  end;'); --END;
      Else
        --INOUT? 应该不允许吧
        Null;
      
      End If;
    
      /*
      --在最后一个转换生成结束后，对最顶层包裹对象生成两个函数声明，第一个，按照原来参数名称，第二个，把所有参数合并为一个参数
      
      
      second generate transfor function for top wrapobj
        if a data argument is 'PL/SQL TABLE' or 'PL/SQL RECORD' 
           then
             if it is a inbind argument we need pltosql_seg function accept warpobj as argument and return orig type
             if it is a outbind argument we need sqltopl_seq function accept orig type as argument and return warpobj
        else then this is a permitive data_type 
      */
    
      If Rec.Sequence = Rec.Max_Seq Then
      
        --datalevel=0
        --打印基础的包裹的过程 start
        --声明部分
        For Rec_Lvl0 In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                           From Cux_All_Arguments_v v
                          Where 1 = 1
                            And v.Package_Name = Upper(p_Package_Name)
                            And v.Object_Name = Upper(p_Object_Name)
                            And v.Data_Level = 0
                          Order By Sequence Asc) Loop
        
          If Rec_Lvl0.Sequence = 1 Then
            Put_Line('  PROCEDURE ' || Rec.Object_Name || '(');
          End If;
        
          Put('    ' || Rec_Lvl0.Argument_Name || ' ' || Rec_Lvl0.In_Out || ' ' ||
              Rec_Lvl0.Wrapped_Objname);
        
          If Rec_Lvl0.Sequence = Rec_Lvl0.Max_Seq Then
            --打印函数结束
            Put_Line(') AS');
          Else
            --打印逗号；
            Put_Line(',');
          End If;
        End Loop;
        --变量部分
        For Rec_Lvl0 In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                           From Cux_All_Arguments_v v
                          Where 1 = 1
                            And v.Package_Name = Upper(p_Package_Name)
                            And v.Object_Name = Upper(p_Object_Name)
                            And v.Data_Level = 0
                          Order By Sequence Asc) Loop
        
          Put_Line('    p_' || Rec_Lvl0.Argument_Name || ' ' ||
                   Rec_Lvl0.Type_Name || '.' || Rec_Lvl0.Type_Subname ||
                   --
                   Case When Rec_Lvl0.In_Out = 'IN' Then
                   ':=' || 'pltosql_' || Rec_Lvl0.Sequence || '(' ||
                   Rec_Lvl0.Argument_Name || ')' Else Null End
                   --
                   || ';');
        
        End Loop;
        --实现部分
        Put_Line(' Begin');
        For Rec_Lvl0 In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                           From Cux_All_Arguments_v v
                          Where 1 = 1
                            And v.Package_Name = Upper(p_Package_Name)
                            And v.Object_Name = Upper(p_Object_Name)
                            And v.Data_Level = 0
                          Order By Sequence Asc) Loop
          If Rec_Lvl0.Sequence = 1 Then
            Put_Line('    ' || Rec.Package_Name || Rec.Object_Name || '(');
          End If;
        
          Put('    ' || Rec_Lvl0.Argument_Name || '=>' || ' p_' ||
              Rec_Lvl0.Argument_Name);
        
          If Rec_Lvl0.Sequence = Rec_Lvl0.Max_Seq Then
          
            --打印函数结束
            Put_Line(');');
          
            --返回值
            For Rec_Sub In (Select v.*, Max(v.Sequence) Over() As Max_Seq
                              From Cux_All_Arguments_v v
                             Where 1 = 1
                               And v.Package_Name = Upper(p_Package_Name)
                               And v.Object_Name = Upper(p_Object_Name)
                               And v.Data_Level = 0
                               And v.In_Out = 'OUT'
                             Order By Sequence Asc) Loop
            
              Put_Line('    ' || Rec_Sub.Argument_Name || ':=' ||
                       'sqltopl_' || Rec_Sub.Sequence || '(p_' ||
                       Rec_Sub.Argument_Name || ');');
            
            End Loop;
          Else
            --打印逗号；
            Put_Line(',');
          End If;
        End Loop;
        Put_Line(' end;');
      
        --打印基础的包裹的过程 end
      
        --打印in参数，out参数合并的过程 start
        --init counter
        l_Counter := 1;
      
        Select Count(Distinct(In_Out))
          Into l_Countend
          From Cux_All_Arguments_v v
         Where 1 = 1
           And v.Package_Name = Upper(p_Package_Name)
           And v.Object_Name = Upper(p_Object_Name)
           And v.Data_Level = 0
           And v.In_Out In ('IN', 'OUT');
      
        If Nvl(l_Countend, 0) >= l_Counter Then
        
          For Rec_Bind_Obj In (Select v.*
                                 From Cux_All_Arguments_v v
                                Where 1 = 1
                                  And v.Package_Name = Upper(p_Package_Name)
                                  And v.Object_Name = Upper(p_Object_Name)
                                  And v.Data_Level = 0
                                  And v.In_Out = 'IN'
                                  And Rownum = 1
                               Union All
                               Select v.*
                                 From Cux_All_Arguments_v v
                                Where 1 = 1
                                  And v.Package_Name = Upper(p_Package_Name)
                                  And v.Object_Name = Upper(p_Object_Name)
                                  And v.Data_Level = 0
                                  And v.In_Out = 'OUT'
                                  And Rownum = 1) Loop
          
            -- 首行打印声明
            If l_Counter = 1 Then
              Put_Line('  PROCEDURE ' || Rec.Object_Name || '(');
            End If;
          
            If Rec_Bind_Obj.In_Out = 'IN' Then
              Put('    P_IN IN ' ||
                  --
                  Substr(Rec.Package_Name || '$' || Rec.Object_Name,
                         0,
                         30 - Lengthb('$in_' || Rec.Object_Id || '_' ||
                                      Rec.Subprogram_Id)) || '$in_' ||
                  Rec.Object_Id || '_' || Rec.Subprogram_Id
                  --
                  
                  );
            End If;
          
            If Rec_Bind_Obj.In_Out = 'OUT' Then
              Put('    P_OUT IN ' ||
                  --
                  Substr(Rec.Package_Name || '$' || Rec.Object_Name,
                         0,
                         30 - Lengthb('$out_' || Rec.Object_Id || '_' ||
                                      Rec.Subprogram_Id)) || '$out_' ||
                  Rec.Object_Id || '_' || Rec.Subprogram_Id
                  --
                  
                  );
            End If;
          
            -- 末行打印结束
            If l_Counter = l_Countend Then
              Put_Line(');');
            Else
              Put_Line(',');
            End If;
          
            l_Counter := l_Counter + 1;
          End Loop;
        
        End If;
      
        --打印结尾
        Put_Line('END ' ||
                 --
                 Substr(Rec.Package_Name || '$' || Rec.Object_Name,
                        0,
                        30 - Lengthb('$pkg_' || Rec.Object_Id || '_' ||
                                     Rec.Subprogram_Id)) || '$pkg_' ||
                 Rec.Object_Id || '_' || Rec.Subprogram_Id
                 --
                 || ';'
                 
                 );
      End If;
    
    End Loop;
  
    --create package body end
    -----------------------------
  
  End;

End Cux_11gapi_Wrapper_Pkg;
/
