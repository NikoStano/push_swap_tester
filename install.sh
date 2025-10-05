#!/bin/bash

SCRIPT_URL="https://raw.githubusercontent.com/NikoStano/push_swap_tester/refs/heads/main/test_push_swap.sh"
NAME="test_ps.sh"
echo "Téléchargement du script..."
curl -fsSL "$SCRIPT_URL" -o "$NAME"
if [ -f "$NAME" ]; then
    chmod +x "$NAME"
    echo "✅ Script téléchargé et rendu exécutable : ./$NAME"
else
    echo "❌ Erreur : le téléchargement a échoué."
    exit 1
fi
./$NAME
