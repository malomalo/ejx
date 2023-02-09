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

function placehold(promise, to, promises) {
    const placeholder = document.createElement( "div");
    to[Array.isArray(to) ? 'push' : 'append'](placeholder);
    
    var newPromise = promise.then((resolvedItems) => {
        if (placeholder.parentElement) {
            repalceejx(placeholder, resolvedItems || "");
        } else if (Array.isArray(resolvedItems)) {
            to.splice(to.indexOf(placeholder), 1, ...resolvedItems);
        } else {
            to.splice(to.indexOf(placeholder), 1, resolvedItems);
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