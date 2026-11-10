#!/bin/bash
cat > /tmp/t.ltl <<'EOT'
G("a" -> F("c" & !"a")) & G(!"d" | X "c")
EOT
ltl2tgba -B --low --hoa -F /tmp/t.ltl
echo ======
ltl2tgba -B --low --lbtt=t -F /tmp/t.ltl
