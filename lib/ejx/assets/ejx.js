function insertBefore(el, items) {
    items.forEach((i) => {
        if ( Array.isArray(i) ) {
            insertBefore(el, i);
        } else if (i instanceof Element) {
            el.insertAdjacentElement('beforebegin', i);
        } else if (i instanceof Node) {
            el.parentNode.insertBefore(i, el)
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

function placehold(promise, to, promises) {
    const placeholder = document.createElement( "div");
    to[Array.isArray(to) ? 'push' : 'append'](placeholder);
    
    var newPromise = promise.then((resolvedItems) => {
        if (resolvedItems !== undefined) {
            if (placeholder.parentElement) {
                repalceejx(placeholder, resolvedItems || "");
            } else if (Array.isArray(resolvedItems)) {
                to.splice(to.indexOf(placeholder), 1, ...resolvedItems);
            } else {
                to.splice(to.indexOf(placeholder), 1, resolvedItems);
            }
        } else {
            if (placeholder.parentElement) {
                placeholder.remove();
            } else {
                to.splice(to.indexOf(placeholder), 1);
            }
        }
        return resolvedItems;
    });
    promises.push(newPromise);
    return newPromise;
}

export function append(items, to, appendMode, promises, awaiter, marker) {
    if (awaiter instanceof Promise) {
        return placehold(awaiter, to, promises);
    }


    if ( Array.isArray(items) ) {
        return items.map((i) => append(i, to, appendMode, promises));
    }
    
    let method = Array.isArray(to) ? 'push' : 'append';
    
    if (items instanceof Promise) {
        return placehold(items, to, promises);
    } else if (typeof items == "function" && items && items.constructor && items.apply && items.call) {
        return placehold(items, to, promises);
    }
    
    if (typeof items === 'string') {
        if (appendMode === 'escape') {
            to[method](items);
        } else {
            var container = document.createElement(Array.isArray(to) ? 'div' : to.tagName);
            container.innerHTML = items;
            to[method](...container.childNodes);
        }
    } else {
        to[method](items);
    }
}