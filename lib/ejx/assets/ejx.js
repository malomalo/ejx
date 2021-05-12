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

export function append(items, to, escape, promises, promiseResults) {
  if ( Array.isArray(items) ) {
    items.forEach((i) => append(i, to, escape, promises));
  } else {
    let method = Array.isArray(to) ? 'push' : 'append';
    if (items instanceof Promise) {
      let holder = document.createElement( "div");
      to[method](holder);
      promises.push( items.then((resolvedItems) => {
          if (holder.parentElement) {
            repalceejx(holder, resolvedItems || promiseResults.flat());
          } else if (Array.isArray(resolvedItems)) {
            to.splice(to.indexOf(holder), 1, ...resolvedItems);
          } else {
            to.splice(to.indexOf(holder), 1, resolvedItems);
          }
      }));
    } else if (typeof items === 'string') {
      if (escape) {
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
}