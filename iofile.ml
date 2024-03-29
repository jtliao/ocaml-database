type wrapper =
  |Int of int
  |Float of float
  |String of string
  |Null

let wrap_to_string (w: wrapper): string =
  match w with
    | Int i -> string_of_int i
    | Float f -> string_of_float f
    | String s -> s
    | Null -> "null"

let read_file (filename: string): string =
  let chan = open_in filename in
  let length = in_channel_length chan in
  let str = Bytes.create length in
  really_input chan str 0 length;
  close_in chan;
  str

let write_file (changes: string) (filename: string): unit =
  let chan = open_out filename in
  output_string chan changes;
  close_out chan

(*Converts a string to its corresponding wrapper. Int and Float strings must
  contain no extra characters*)
let string_to_wrap (str: string): wrapper =
  try
    let i = int_of_string str in
    Int i
  with
  | _ ->
    (try
      let fl = float_of_string str in
      Float fl
    with
    | _ -> if str = "null" then Null else String str)

let rec string_to_array (str: string) (arr: wrapper array) (build: string):
  wrapper array =
  let char_at = Bytes.get str 0 in
  let rest = Bytes.sub str 1 ((Bytes.length str)-1 ) in
  match char_at with
    | '|' -> if build = "" then string_to_array rest arr ""
      else string_to_array rest (Array.append arr [|string_to_wrap build|]) ""
    | '\n' -> arr
    | _ -> string_to_array rest arr (build^(Bytes.make 1 char_at))

(*Converts a string array to a (string,int) Hashtbl*)
let array_to_hashtbl (arr: string array): (string,int) Hashtbl.t =
  let tbl = Hashtbl.create (Array.length arr) in
  for i = 0 to (Array.length arr - 1) do
    Hashtbl.replace tbl arr.(i) i
  done;
  tbl

(*Recursively updates header and rows until the string is empty, then returns
  the Hashtbl.t tuple (header,rows).*)
let rec string_to_dict_help (str: string) (header: (string,int) Hashtbl.t)
  (rows: (int, wrapper array) Hashtbl.t) (rownum: int): (string,int) Hashtbl.t *
  (int, wrapper array) Hashtbl.t =
  if str = "" then (header,rows)
  else if header = (Hashtbl.create 0) then
    let nextstart = (Bytes.index str '\n')+1 in
    let next = Bytes.sub str nextstart ((Bytes.length str)-nextstart) in
    let columns = Array.map wrap_to_string (string_to_array str [||] "") in
    let coltbl = array_to_hashtbl columns in
    string_to_dict_help next coltbl rows 0
  else
    let nextstart = (Bytes.index str '\n')+1 in
    let next = Bytes.sub str nextstart ((Bytes.length str)-nextstart) in
    let arr = string_to_array str [||] "" in
    (Hashtbl.replace rows rownum arr);
    string_to_dict_help next header rows (rownum+1)

let string_to_dict (s: string): (string, int) Hashtbl.t *
  (int, wrapper array) Hashtbl.t =
  string_to_dict_help s (Hashtbl.create 0) (Hashtbl.create 0) 0

(*Convert a wrapper array to a string for printing*)
let array_to_string (arr: wrapper array): string =
  Array.fold_left (fun acc x -> acc^(wrap_to_string x)^"|") "|" arr

let str_arr_to_string (arr: string array): string =
  Array.fold_left (fun acc x -> acc^x^"|") "|" arr

let hash_to_array (tbl: (string, int) Hashtbl.t): string array =
  let arr = Array.make (Hashtbl.length tbl) "Null" in
  Hashtbl.iter (fun k v -> Array.set arr v k) tbl;
  arr

let dict_to_string (t1,t2: (string, int) Hashtbl.t *
  (int, wrapper array) Hashtbl.t): string =
  let dictstring = ref ((str_arr_to_string (hash_to_array t1))^"\n") in
  for i = 0 to (Hashtbl.length t2 - 1) do
    dictstring := !dictstring^(array_to_string (Hashtbl.find t2 i))^"\n"
  done;
  !dictstring