#!/bin/bash

#fisierele de input si output
file=$1
file_output="${file%.html}_prettyPrinter.html"

#taguri care nu necesita indentare: self-closing si !DOCTYPE
void_tags="area base br col embed hr img input link meta param source track wbr !DOCTYPE"

#array cu tag-urile de deschidere
opened_tag=()

#functie pentru indentare
output_tabs(){
    local tabs=""
    if [[ $1 != 0 ]]; then
        local cnt=0
        while [ $cnt -lt $1 ]; do
            tabs+='\t'
            cnt=$((cnt+1))
        done
    fi
    echo -ne "$tabs"
}

opening_tags(){
    local opening_tag=$1
    #verificare daca e self closing, <!DOCTYPE html>;
    if [[ " $void_tags " =~ " $opening_tag " ]]; then
        echo "$(output_tabs $indent)$line"
    #verificare  <style>,<script>;
    elif [[ "$opening_tag" == "script" || "$opening_tag" == "style" ]]; then
        echo "$(output_tabs $indent)$line"
        in_literal=true
        literal_tag="$opening_tag"
        indent=$((indent+1))
    else
        echo "$(output_tabs $indent)$line"
        opened_tag+=("$opening_tag")
        indent=$((indent+1))
    fi
}



format_file(){
    local indent=0
    local tag
    
    local literal_tag=""
    local in_literal=false
    local in_comment=false
    
    local file_formated=$(tr '\n' ' ' < "$file" | sed 's/<[^>]*>/\n&\n/g')

    while IFS= read -r line;do
        line=$(sed -E 's/^[[:space:]]+|[[:space:]]+$//g' <<< "$line") #scapa de toate spatiile albe de la inceput si sfarsit
        [[ -z $line ]] && continue

        if [[ "$line" =~ ^\<!--.* ]]; then
            echo "$(output_tabs $indent)$line"
            if [[ ! "$line" =~ --\>$ ]]; then
                in_comment=true 
            fi
            continue
        fi
        if [[ "$in_comment" == "true" ]]; then
            echo "$(output_tabs $indent)$line"
            if [[ "$line" =~ --\>$ ]]; then
                in_comment=false 
            fi
            continue
        fi

        if [[ "$line" =~ ^\</.*\>$ ]]; then
            tag=$(echo "$line"|sed -E 's|^</([A-Za-z0-9]+)>$|\1|') 
            local length=$((${#opened_tag[@]} - 1 ))

            if [[ "$in_literal" == "true" ]]; then
                if [[ "$tag" == "$literal_tag" ]]; then
                    indent=$((indent-1))
                    echo "$(output_tabs $indent)$line"
                    in_literal=false
                    literal_tag=""
                fi
            elif [[ "${opened_tag[$length]}" == "$tag" ]]; then
                indent=$((indent-1))
                echo "$(output_tabs $indent)$line"
                unset 'opened_tag[$length]'
            else 
                echo "Eroare: Tag-ul de inchidere </$tag> nu se potriveste cu ultimul tag deschis, <${opened_tag[$length]}>."
                exit 1
            fi
        
        elif [[ "$line" =~ ^\<.*\>$ ]]; then
            tag=$(echo "$line"|sed -E 's/^<([!A-Za-z0-9]+).*>$/\1/') 
            opening_tags $tag
        else
            #formatare speciala pentru <script>, <style>
            if [[ "$in_literal" == "true" ]]; then
                line=$(echo "$line" | tr -s '[:space:]' ' ')
            fi
            echo "$(output_tabs $indent)$line"
        fi

    done <<< "$file_formated"
}

if [[ -z "$file" ]]; then
    echo "Eroare: Nu este mentionat numele fisierului."
    exit 1
fi

if [[ ! -f $file ]]; then
    echo "Eroare: Fisierul mentionat nu exista."
    exit 1
fi

> "$file_output"
format_file > "$file_output"
echo "Programul formatat se afla in fisierul $file_output."