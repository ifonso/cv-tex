# Compila com LuaLaTeX (o motor de layout usa callbacks Lua).
$pdf_mode = 4;
$lualatex = 'lualatex -interaction=nonstopmode -file-line-error -synctex=1 %O %S';
@default_files = ('main.tex');
$out_dir = 'build';

# content/phone.tex é opcional (ignorado pelo git). O latexmk não percebe quando
# ele é criado ou apagado, então força a recompilação quando o estado muda.
my $phone = 'content/phone.tex';
my $stamp = "$out_dir/.phone-state";
my $state = -e $phone ? 'mtime ' . (stat $phone)[9] : 'none';
my $last  = -e $stamp ? do { local (@ARGV, $/) = $stamp; <> } : '';
if ($state ne $last) {
  $go_mode = 1;
  mkdir $out_dir;
  if (open(my $fh, ">", $stamp)) { print $fh $state; close $fh; }
}
