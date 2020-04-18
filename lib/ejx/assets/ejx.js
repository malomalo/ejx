function repalceejx(el, withItems) {
  if ( Array.isArray(withItems) ) {
    withItems.forEach((i) => {
      if (i instanceof Node) {
        el.insertAdjacentElement('beforebegin', i)
      } else {
        // el.insertAdjacentHTML()
        el.insertAdjacentText('beforebegin', i)
      }
    })
    el.remove();
  } else {
    el.replaceWith(withItems);
  }
}

export function append(items, to, escape, promises, promise_results) {
  if ( Array.isArray(items) ) {
    items.forEach((i) => append(i, to, escape, promises));
  } else {
    let method = Array.isArray(to) ? 'push' : 'append';
    
    if (items instanceof Promise) {
      let holder = document.createElement( "div");
      to[method](holder);
      promises.push( items.then((resolvedItems) => {
        repalceejx(holder, promise_results || resolvedItems)
      }));
    } else {
      to[method](items);
    }

  }
}