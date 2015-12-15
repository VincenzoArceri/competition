module COMPETITION-SYN
	
	syntax Decl ::= "var" Ids ";" | "mutex" Ints ";"

  	syntax Exp ::= Int | Id | Bool
               | "(" Exp ")"             [bracket]				// DONE
               > "-" Exp                 [strict]				// DONE
               | "read" "(" ")"									// DONE
               > left:											// DONE
                 Exp "*" Exp             [strict, left]			// DONE
               | Exp "/" Exp             [strict, left]			// DONE
               | Exp "%" Exp             [strict, left]			// DONE
               > left:											// DONE
                 Exp "+" Exp             [strict, left]			// DONE
               | Exp "-" Exp             [strict, left]			// DONE
               > non-assoc:										// DONE
                 Exp "<" Exp             [strict, non-assoc]	// DONE
               | Exp "<=" Exp            [strict, non-assoc]	// DONE
               | Exp ">" Exp             [strict, non-assoc]	// DONE
               | Exp ">=" Exp            [strict, non-assoc]	// DONE
               | Exp "==" Exp            [strict, non-assoc]	// DONE
               | Exp "!=" Exp            [strict, non-assoc]	// DONE
               > "not" Exp                 [strict]				// DONE
               > left:											// DONE
                 Exp "&&" Exp           [strict(1), left]		// DONE
               | Exp "||" Exp            [strict(1), left]		// DONE
               > "execute" Block								// DONE
               //> Id "=" Exp              [strict(2), right]		// DONE

  syntax Ids  ::= List{Id,","}
  syntax Exps ::= List{Exp,","}          [strict]  // automatically hybrid now
  syntax Ints ::= List{Int, ","}

  syntax Block ::= "{" "}"								
                | "{" Stmts "}"							

  syntax Stmt ::= Decl | Block
                | Exp ";"                               [strict]		   // DONE
                | Id "=" Exp ";"             			[strict(2)]
                | "if" "(" Exp ")" Block "else" Block   [avoid, strict(1)] // DONE
                | "if" "(" Exp ")" Block								   // DONE
                | "while" "(" Exp ")" Block								   // DONE
                | "return" Exp ";"                      [strict]
                | "print" "(" Exp ")" ";"              	[strict]			   // DONE

                | "lock" Int ";"                       	[strict]			   // DONE
                | "unlock" Int ";"                     	[strict]			   // DONE
     
  syntax Stmts ::= Stmt
                 | Stmts Stmts                          [right]

  rule if (E) S => if (E) S else {}                                 [macro]
  //rule var E1:Exp, E2:Exp, Es:Exps; => var E1; var E2, Es;          [macro]
  //rule var X:Id = E; => var X; X = E;                               [macro]

endmodule


module COMPETITION
	imports COMPETITION-SYN
	imports SUBSTITUTION
	imports BUILTIN-SYNTAX-HOOKS

  syntax Val ::= Int | Bool
  syntax Vals ::= List{Val,","}
  syntax Exp ::= Val
  syntax KResult ::= Val

  configuration <T color="red">
                  <threads color="orange">
                    <thread multiplicity="*" color="yellow">
                      <k color="green"> $PGM:Stmts </k>
                      <env color="violet"> .Map </env>
                      <holds color="black"> .Set </holds>
                      <id color="pink"> 0 </id>
                    </thread>
                  </threads>

                  <genv color="pink"> .Map </genv>
                  <store color="white"> .Map </store>
                  
                  <streams>
                 	<in color="magenta" stream="stdin"> .List </in>
                  	<out color="brown" stream="stdout"> .List </out>
                  </streams>

                  <mutex> .Map </mutex>
                </T>

  rule not T:Bool => notBool(T)
  rule true && E => E
  rule false && _ => false
  rule true  || _ => true
  rule false || E => E

  rule I1 + I2 => I1 +Int I2
  rule I1 - I2 => I1 -Int I2
  rule I1 * I2 => I1 *Int I2
  rule I1 / I2 => I1 /Int I2 when I2 =/=Int 0
  rule I1 % I2 => I1 %Int I2 when I2 =/=Int 0
  rule - I => 0 -Int I
  rule I1 < I2 => I1 <Int I2
  rule I1 <= I2 => I1 <=Int I2
  rule I1 > I2 => I1 >Int I2
  rule I1 >= I2 => I1 >=Int I2

  rule V1:Val == V2:Val => V1 ==K V2
  rule V1:Val != V2:Val => V1 =/=K V2


  rule if (true) S else _ => S
  rule if (false) _ else S => S

  rule while (E) S => if (E) {S while(E)S}  	[structural]

  rule 	<k> read() => I ...</k> 
  		<in> ListItem(I:Int) => .List ...</in>  [read]

  rule 	<k> print(I:Int) ; => I ... </k> 
  		<out>... .List => ListItem(I) </out> 	[print]

  rule _:Val; => .K

  rule <k> lock I:Int ; => I ; ... </k>
  		<holds> Holds:Set => Holds SetItem(I) </holds> 
  		<mutex>	... I |-> (1 => 0) ... </mutex> when notBool(I in Holds)

  rule <k> unlock I:Int ; => I ; ... </k>
  		<holds> Holds:Set => Holds -Set SetItem(I) </holds>
  		<mutex>	... I |-> (0 => 1) ... </mutex> when (I in Holds)


  rule <k> X:Id => I:Int ...</k>
       <env>... X |-> L ...</env>
       <store>... L |-> I:Int ...</store>

  rule <thread>...
         <k> execute S:Block => T:Int ...</k>
         <env> Env:Map </env>
       ...</thread>
       (. => <thread>...
               <k> S </k>
               <env> Env:Map </env>
               <id> T </id>
         ... </thread>) when fresh(T:Int)

    rule <k> mutex (I:Int, I1:Ints => I1) ; ... </k>
		<mutex> Mutex:Map => Mutex[1/I] </mutex>

	rule mutex .Ints ; => .K


   rule <k> var (X:Id,X1:Ids => X1) ; ... </k>
		<env> Rho:Map => Rho[L:Int/X] </env>
		<store> Delta:Map => Delta[0 /L] </store> when fresh(L:Int)

	rule <k> X:Id = I:Int ; => I; ... </k>
		<env> ... X |-> N:Int ... </env>
		<store> ... N |-> (_ => I) </store> 

	rule V:Val ; => .K				[structural]
	rule var .Ids ; => .K 			[structural]

  	rule S1:Stmts S2:Stmts => S1 ~> S2  [structural]

  	rule { S:Stmts } => S

endmodule