# Compare digit runs by their numeric value without losing precision on long names.
def natural_name_key:
    ascii_downcase | [scan("[0-9]+|[^0-9]+") |
        if test("^[0-9]+$") then
            . as $digits | sub("^0+"; "") | (if . == "" then "0" else . end) as $number |
            [0, ($number | length), $number, ($digits | length)]
        else [1, .] end];
