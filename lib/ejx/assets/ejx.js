function insertBefore(el, items) {
    items.forEach((i) => {
        if ( Array.isArray(i) ) {
            insertBefore(el, i);
        } else if (i instanceof Element) {
            el.insertAdjacentElement('beforebegin', i);
        } else if (i instanceof Text) {
            // TextNode#toString() => "[object Text]" so we need to get it ourselves,
            // Not sure why but the test in Node do not reflect this.
            el.insertAdjacentText('beforebegin', i.textContent);
        } else {
            el.insertAdjacentText('beforebegin', i);
        }
    });
}

function repalceejx(el, withItems) {
    if ( Array.isArray(withItems) ) {
        insertBefore(el, withItems);
        el.remove();
    } else {
        el.replaceWith(withItems);
    }
}

export function append(items, to, escape, unreturnedItems) {
    if ( Array.isArray(items) ) {
        items.forEach((i) => append(i, to, escape, unreturnedItems));
    } else {
        let method = Array.isArray(to) ? 'push' : 'append';
        if (items instanceof Promise) {
            let holder = document.createElement("div");
            to[method](holder);
            holder.__to = to;
            
            items.then(resolvedItems => {
                resolvedItems = resolvedItems || unreturnedItems?.flat()
                resolvedItems = resolvedItems === undefined ? "" : resolvedItems
                resolvedItems = Array.isArray(resolvedItems) ? resolvedItems : [resolvedItems]
                if (holder.parentElement) {
                    repalceejx(holder, resolvedItems || "");
                } else {
                    holder.__to.splice(holder.__to.indexOf(holder), 1, ...resolvedItems);
                }
                resolvedItems.forEach(i => {
                    if (typeof i == "object") i.__to = holder.__to
                })
                delete holder.__to
            })
        } else if (typeof items === 'string') {
            if (escape) {
                to[method](items);
            } else {
                var container = document.createElement(Array.isArray(to) ? 'div' : to.tagName);
                container.innerHTML = items;
                to[method](...container.childNodes);
            }
        } else if (items !== undefined) {
            to[method](items);
        }

    }
}