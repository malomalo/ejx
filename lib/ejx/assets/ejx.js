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

export function append(items, to, appendModeOrBlock, promises, marker) {
    if (typeof appendModeOrBlock !== 'function') {
        if ( Array.isArray(items) ) {
            return items.map((i) => append(i, to, appendModeOrBlock, promises));
        }
        
        let method = Array.isArray(to) ? 'push' : 'append';
        
        if (items instanceof Promise) {
          let holder = document.createElement( "div");
          holder.className = 'placeholder';
          to[method](holder);
          
          var newPromise = items.then((resolvedItems) => {
              resolvedItems = resolvedItems !== undefined ? resolvedItems : promiseResults?.flat();
              if (holder.parentElement) {
                  repalceejx(holder, resolvedItems || "");
              } else if (Array.isArray(resolvedItems)) {
                  to.splice(to.indexOf(holder), 1, ...resolvedItems);
              } else {
                  to.splice(to.indexOf(holder), 1, resolvedItems);
              }
              
              return resolvedItems;
          });
          promises.push(newPromise);
          return newPromise;
        } else if (typeof items === 'string') {
            if (appendMode === 'escape') {
                to[method](items);
            } else if (appendMode === 'unescape') {
                var container = document.createElement(Array.isArray(to) ? 'div' : to.tagName);
                container.innerHTML = items;
                to[method](...container.childNodes);
            }
        } else {
            to[method](items);
            return items;
        }
	} else {
		
	}
}











var htmlEscapes = {
  '&': '&amp',
  '<': '&lt',
  '>': '&gt',
  '"': '&quot',
  "'": '&#39'
}

function toHTML(els) {
  if (Array.isArray(els)) {
    return els.map((i) => toHTML(i))
  } else {
    if (typeof els === 'string') {
      return els.replace(/[&<>"']/g, (chr) => htmlEscapes[chr])
    } else if (els instanceof Text) {
      return els.textContent;
    } else if (els instanceof Element || els instanceof Node) {
      return els.outerHTML;
    } else {
      return els
    }
  }
}
