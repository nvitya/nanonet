
if (typeof(Array.isArray) === 'undefined')
{
  Array.isArray = function(arg)
  {
    return Object.prototype.toString.call(arg) === '[object Array]';
  };
}

//------------------------------------------------------------------------------ event handling

var dc_evdata = {};
var dc_eventdata = dc_evdata;  // alias

function dc_callevent(event, func, args, self)
{
  var fargs;

  if (Array.isArray(args))
  {
	 fargs = [];
    for (var n = 0; n < args.length; n++)
    {
      if (args[n] === dc_evdata)
      {
        fargs[n] = event;
      }
		else
		{
		  fargs[n] = args[n];
		}
    }
  }
  else if (args === dc_evdata)
  {
    fargs = [event];
  }
  else if (args !== undefined && args != null)
  {
    fargs = [args];

    if (typeof(args) == 'object')
    {
      if (args.event === undefined) fargs[0].event = event;
    }
  }
  else
  {
    fargs = [event];
  }

  if (self)
  {
    func.apply(self, fargs);
  }
  else
  {
    func.apply(null, fargs);
  }
}

function dc_handleevent(func, args, self)
{
  return function(event)
  {
    dc_callevent(event, func, args, self);
  };
}

function dc_delevent(obj, name)
{
  obj = dc_get(obj);

  if (obj.dc_eventlisteners !== undefined)
  {
    if (name.substr(0, 2) == 'on')
    {
      name = name.substr(2);
    }

    var f = obj.dc_eventlisteners[name];

    if (f)
    {
      if (window.removeEventListener)
      {
        obj.removeEventListener(name, f);
      }
      else
      {
        obj.detachEvent('on' + name, f);
      }

      obj.dc_eventlisteners[name] = null;
    }
  }

  return obj;
}

function dc_addevent(obj, name, func, args, self)
{
  obj = dc_delevent(obj, name);

  var f = dc_handleevent(func, args, self);

  if (name.substr(0, 2) == 'on')
  {
    name = name.substr(2);
  }

  if (window.addEventListener)
  {
    obj.addEventListener(name, f);
  }
  else
  {
    obj.attachEvent('on' + name, f);
  }

  if (obj.dc_eventlisteners === undefined)
  {
    obj.dc_eventlisteners = {};
  }

  obj.dc_eventlisteners[name] = f;
}

//------------------------------------------------------------------------------ basic functions

function dc_event(obj, name, def)
{
  if (typeof(def) == 'function')
  {
    dc_addevent(obj, name, def, [], null);
  }
  else if (Array.isArray(def))
  {
    var func = def[0];
    var args = def[1] || [];
    var self = def[2] || null;

    if (!Array.isArray(args)) args = [args];

    dc_addevent(obj, name, func, args, self);
  }
  else
  {
    dc_addevent(obj, name, def.func, def.args, def.self);
  }
}

function dc_get(obj)
{
  if (typeof(obj) === 'string')
  {
    obj = document.getElementById(obj);
  }

  return obj;
}

function dc_style(obj, style)
{
  obj = dc_get(obj);

  if (typeof(style) == 'string')
  {
    obj.style.cssText = style;
  }
  else
  {
    for (var key in style)
    {
      var val = style[key];

      if (key.match(/^(?:border|fontSize|height|margin|minWidth|minHeight|padding|width)$/))
      {
        if (String(val).match(/^\d+$/)) val = val + 'px';
      }

      obj.style[key] = val;
    }
  }
}

function dc_add_dynamicclass(obj, name, def)
{
  var sheet = dc_get(name);

  if (!sheet)
  {
    sheet = dc_new('style', { id : name });
    dc_add(document.body, sheet);
  }

  sheet.innerHTML = '.' + name + ' ' + def;

  if (obj)
  {
    if (Array.isArray(obj))
    {
      for (var i = 0; i < obj.length; i++)
      {
        dc_attr(obj[i], { 'class' : name });
      }
    }
    else
    {
      if (typeof(obj) == 'object')
      {
        dc_attr(obj, { 'class' : name });
      }
    }
  }
}

function dc_setselect(obj, def)
{
  obj = dc_get(obj);

  for (var i = 0; i < obj.options.length; i++)
  {
    if (obj.options[i].value == def)
    {
      obj.selectedIndex = i;
      return;
    }
  }

  obj.selectedIndex = 0;
}

function dc_attr(obj, attr)
{
  if (attr === undefined || attr == null) return;

  obj = dc_get(obj);

  if (typeof(attr) == 'string')
  {
    dc_style(obj, attr);
    return;
  }

  for (var key in attr)
  {
    var val = attr[key];
    var lck = key.toLowerCase();

    if (lck == 'text')
    {
      dc_add(obj, dc_text(val));
    }
    else if (lck == 'html')
    {
      dc_add(obj, dc_html(val));
    }
    else if (lck == 'style')
    {
      dc_style(obj, val);
    }
    else if (lck == 'name')
    {
      var narr = String(val).split('+');
      if (narr.length > 1)
      {
        obj.id = narr[0]+narr[1];
        obj.name = narr[1];
      }
      else
      {
        obj.name = val;
      }
    }
    else if (lck == 'parent')
    {
      dc_add(val, obj);
    }
    else if (lck == 'event')
    {
      dc_event(obj, val.name, val);
    }
    else if (lck.match(/^(?:on)?(?:blur|change|click|focus|keydown|keypress|keyup|mouseout|mouseover|mousedown|mouseup)$/))
    {
      dc_event(obj, lck, val);
    }
    else if (lck == 'value' && obj.nodeName == 'SELECT')
    {
      dc_setselect(obj, val);
    }
    else
    {
      obj.setAttribute(key, val);
      obj[key] = val;
    }
  }
}

function dc_new(type, attr)
{
  var obj = document.createElement(type);
  dc_attr(obj, attr);
  return obj;
}

function dc_clone(obj, deep)
{
  var source = dc_get(obj);

  if (deep !== undefined && deep)
  {
    return source.cloneNode(true);
  }
  else
  {
    return source.cloneNode(false);
  }
}

function dc_add(obj, args)
{
  var parent = dc_get(obj);
  var prevobj = parent;

  for (var i = 1; i < arguments.length; i++)
  {
    var child = arguments[i];

    if (Array.isArray(child))
    {
      var params = [prevobj];
      dc_add.apply(null, params.concat(child));
    }
    else
    {
      if (typeof(child) != 'object')  child = dc_text(child);

      parent.appendChild(child);
      prevobj = child;
    }
  }

  return parent;
}

function dc_replace(obj, args)
{
  dc_clear(obj);
  dc_add.apply(null, arguments);
}

function dc_del(obj)
{
  obj = dc_get(obj);
  if (obj.parentNode) obj.parentNode.removeChild(obj);
}

function dc_clear(obj)
{
  obj = dc_get(obj);

  while (obj.firstChild)
  {
    obj.removeChild(obj.firstChild);
  }
}

//------------------------------------------------------------------------------ output helpers

function dc_div(attr)
{
  return dc_new('div', attr);
}

function dc_span(attr)
{
  return dc_new('span', attr);
}

function dc_html(html, attr)
{
  var obj = dc_span(attr);
  obj.innerHTML = html;
  return obj;
}

function dc_text(text, attr)
{
  if (attr !== undefined && attr != null)
  {
    return dc_add(dc_span(attr), document.createTextNode(text));
  }
  else
  {
    return document.createTextNode(text);
  }
}

function dc_p(attr)
{
  return dc_new('p', attr);
}

function dc_h(size, attr)
{
  return dc_new('h' + size, attr);
}

function dc_hr(attr)
{
  return dc_new('hr', attr);
}

function dc_br(attr)
{
  return dc_new('br', attr);
}

function dc_hspace(size)
{
  return dc_span('margin-left: '+size+'px');
}

function dc_vspace(size)
{
  return dc_div('height: '+size+'px');
}

function dc_a(attr)
{
  if (typeof(attr) != 'object') attr = {};
  if (attr.href === undefined || attr.href == null) attr.href = 'javascript:void(0);';
  return dc_new('a', attr);
}

function dc_a_text(text, attr)
{
  return dc_add( dc_a(attr), dc_text(text) );
}

function dc_a_html(html, attr)
{
  return dc_add( dc_a(attr), dc_html(html) );
}

function dc_table(attr)
{
  return dc_new('table', attr);
}

function dc_tr(attr)
{
  return dc_new('tr', attr);
}

function dc_td(attr)
{
  return dc_new('td', attr);
}

function dc_td_text(text, attr)
{
  return dc_add(dc_td(attr), dc_text(text));
}

function dc_td_html(html, attr)
{
  return dc_add(dc_td(attr), dc_html(html));
}

function dc_th(attr)
{
  return dc_new('th', attr);
}

function dc_th_text(text, attr)
{
  return dc_add(dc_th(attr), dc_text(text));
}

function dc_th_html(html, attr)
{
  return dc_add(dc_th(attr), dc_html(html));
}

//------------------------------------------------------------------------------ input helpers

function dc_form(attr)
{
  return dc_new('form', attr);
}

function dc_input(type, name, value, attr)
{
  var obj = dc_new('input', attr);
  dc_attr(obj, {type:type, name:name, value:value});
  return obj;
}

function dc_input_text(name, value, attr)
{
  if (value === undefined || value === null)
  {
    value = '';
  }
  return dc_input('text', name, value, attr);
}

function dc_input_hidden(name, value)
{
  return dc_input('hidden', name, value);
}

function dc_input_button(name, value, attr)
{
  return dc_input('button', name, value, attr);
}

function dc_input_checkbox(name, checked, attr)
{
  var obj = dc_input('checkbox', name, null, attr);
  dc_attr(obj, {checked:checked});
  return obj;
}

function dc_input_textarea(name, value, attr)
{
  var obj = dc_new('textarea', attr);
  dc_attr(obj, {name:name, value:value});
  return obj;
}

function dc_options(obj, defvalue, options, idfield, namefield)
{
  obj = dc_get(obj);
  dc_clear(obj);

  for (var idx in options)
  {
    var data = options[idx];
    dc_add(obj, dc_new('option', {value:data[idfield], text:data[namefield]}));
  }

  dc_setselect(obj, defvalue);
}

function dc_input_select(name, defvalue, options, idfield, namefield, attr)
{
  var obj = dc_new('select', attr);
  dc_options(obj, defvalue, options, idfield, namefield);
  dc_attr(obj, {name:name});
  return obj;
}

function dc_collect(obj)
{
  var result = {};

  function dc_collect_recursive(root)
  {
    for (var child = root.firstChild; child; child = child.nextSibling)
    {
      if (child.nodeName.match(/^(?:INPUT|SELECT|TEXTAREA)$/))
      {
        if (child.name)
        {
          if (child.type == 'checkbox')
          {
            result[child.name] = (child.checked ? '1' : '0');
          }
          else
          {
            result[child.name] = child.value;
          }
        }
      }
      else
      {
        dc_collect_recursive(child);
      }
    }
  }

  dc_collect_recursive( dc_get(obj) );

  return result;
}

function dc_urlencode(obj)
{
  var strs = [];
  for (var p in obj)
  {
    if (obj.hasOwnProperty(p)) // Checking for hasOwnProperty on the object makes JSLint/JSHint happy, and it prevents accidentally serializing methods of the object or other stuff if the object is anything but a simple dictionary
    {
      strs.push( encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]) );
    }
  }
  return strs.join("&");
}

//------------------------------------------------------------------------------ tooltip

function dc_tooltip(atarget, atext, aparams)  // also works like this: function dc_tooltip(obj)
{
  var obj;
  if (arguments.length > 1)
  {
    obj = aparams || {};
    obj.appender = atarget;
    obj.text = atext;
  }
  else
  {
    obj = atarget;
  }

  var appender = obj.appender || document.body || document.getElementsByTagName('body')[0];
  var width = obj.width || 300;
  var bar = obj.content || dc_div({ style : 'font-weight: normal; text-align: left; box-shadow: 5px 5px 5px; border:1px solid black; background-color: #fbf0e5; color: #000000; padding:5px; width:' + width + 'px;' });
  var text = obj.text || '';
  var plusx = obj.plusx || 15;
  var plusy = obj.plusy || 4;
  bar.style.display = 'none';

  var onmouseout = obj.onmouseout || function() { bar.style.display = 'none'; };

  if (obj.text)
  {
    dc_add(bar, dc_text(obj.text));
  }

  bar.style.position = 'absolute';
  dc_add(appender, bar);

  dc_addevent(appender, 'onmouseover',
    function(e, bar)
    {
      bar.style.zIndex = dc_maxz() + 1;

      if (obj.onmouseover) obj.onmouseover(e, bar);
    },
    [ dc_evdata, bar ]
  );

  dc_addevent(appender, 'onmousemove',
    function(e)
    {
      var x = e.clientX;
      var y = e.clientY;

      var doc = document.documentElement;
      var left = (window.pageXOffset || doc.scrollLeft) - (doc.clientLeft || 0);
      var top = (window.pageYOffset || doc.scrollTop)  - (doc.clientTop || 0);

      bar.style.left = (x + left + plusx) + 'px';
      bar.style.top  = (y + top + plusy) + 'px';
      bar.style.display = 'block';

      if (obj.onmousemove) obj.onmousemove(e, bar);
    }
  );

  dc_addevent(appender, 'onmouseout', onmouseout, [ dc_evdata, bar ]);
}

//------------------------------------------------------------------------------ drag&drop helpers

function dc_maxz()
{
  var elems = document.getElementsByTagName('*');
  if (!elems.length) return 0;

  var z = 0;

  for (var i = 0; i < elems.length; i++)
  {
    if (elems[i].style.position && elems[i].style.zIndex)
    {
      z = Math.max(z, parseInt(elems[i].style.zIndex));
    }
  }

  return z;
}

function dc_dragging(drag, obj)
{
  drag = dc_get(drag);

  var dx, dy, scrolltop, scrollleft;

  var content = (obj && obj.content) ? dc_get(obj.content) : drag;
  var clickfunc = (obj && obj.clickfunc) ? obj.clickfunc : false;
  var movefunc = (obj && obj.movefunc) ? obj.movefunc : false;
  var dropfunc = (obj && obj.dropfunc) ? obj.dropfunc : false;

  dc_addevent(drag, 'mousedown',
    function(e)
    {
      Prevent(e);

      content.style.position = 'absolute';
      content.style.zIndex = dc_maxz() + 1;

      var doc = document.documentElement;
      scrolltop = (window.pageYOffset || doc.scrollTop)  - (doc.clientTop || 0);
      scrollleft = (window.pageXOffset || doc.scrollLeft) - (doc.clientLeft || 0);

      var rect = content.getBoundingClientRect();
      dx = e.clientX - rect.left;
      dy = e.clientY - rect.top;

      if (clickfunc) clickfunc(content, drag);

      dc_addevent(window, 'mousemove', Move);

      dc_addevent(window, 'mouseup',
        function()
        {
          if (dropfunc) dropfunc(content, drag);

          dc_delevent(window, 'mousemove', Move);
        }
      );
    }
  );

  function Move(e)
  {
    content.style.left = (e.clientX - dx + scrollleft) + 'px';
    content.style.top = (e.clientY - dy + scrolltop) + 'px';

    if (movefunc) movefunc(content, drag);
  }

  function Prevent(e)
  {
    if (e && e.preventDefault)
    {
      e.preventDefault();
    }
    else
    {
      window.event.returnValue = false;
    }
    return false;
  }
}

function dc_center(elem, top, left)
{
  elem = dc_get(elem);
  elem.style.position = 'absolute';

  var doc = document.documentElement;
  scrolltop = (window.pageYOffset || doc.scrollTop)  - (doc.clientTop || 0);
  scrollleft = (window.pageXOffset || doc.scrollLeft) - (doc.clientLeft || 0);

  var rect = elem.getBoundingClientRect();
  var dx = screen.width / 2 - rect.left;
  var dy = screen.height / 2 - rect.top;

  var w = window,
  d = document,
  e = d.documentElement,
  g = d.getElementsByTagName('body')[0],
  x = w.innerWidth || e.clientWidth || g.clientWidth,
  y = w.innerHeight|| e.clientHeight|| g.clientHeight;

  var ctop  = (top >= 0 ? top + scrolltop : (y / 2 - rect.height / 2) + scrolltop);
  var cleft = (left >= 0 ? left + scrollleft : (x / 2 - rect.width / 2) + scrollleft);

  if (ctop < 0) ctop = 0;
  if (cleft < 0) cleft = 0;

  elem.style.top = ctop + 'px';
  elem.style.left = cleft + 'px';
}

//------------------------------------------------------------------------------ window helpers

function dc_screen()
{
  var b = document.body, e = document.documentElement;
  return {
    w:Math.max(b.scrollWidth, e.scrollWidth, b.clientWidth, e.clientWidth),
    h:Math.max(b.scrollHeight, e.scrollHeight, b.clientHeight, e.clientHeight)
  }
}

function DCWIN(args)
{
  //--- internal state

  var title = '';
  var width = 800;
  var height = 0;
  var content = '';
  var modal = false;
  var url = '';

  var window_div = dc_div({style:'border:4px solid #000040; background-color:#F8F8F8; box-shadow:4px 4px 6px #707070;'}); // width:608px;
  var header_div = dc_div({style:'width:100%; height:25px; background-color:#000040; color:#FFFFFF; font-weight:bold; padding-bottom:4px; line-height:25px;'});
  var title_div = dc_div({style:'float:left;'});
  var content_div = dc_div();

  var mask_div = dc_div({style:'position:absolute; top:0px; left:0px; background-color:#000000; opacity:0.5; filter:alpha(opacity=50);'});

  var resize_mask = function(e)
  {
    dc_center(window_div);
    var s = dc_screen();
    dc_style(mask_div, {width:s.w, height:s.h});
  }

  //--- exported data and functions

  this.content_div = content_div;

  this.Update = function(args)
  {
    if (window_div && typeof(args) == 'object')
    {
      title = args.title || title;
      width = (args.width && args.width > 0) ? args.width : 600;
      height = (args.height && args.height > 0) ? args.height : 0;
      content = args.content || content;
      modal = args.modal || modal;
      url = args.url || url;

      if (modal)
      {
        dc_delevent(header_div, 'mousedown');
        dc_style(header_div, {cursor:'default'});

        if (!mask_div.parentNode) dc_add(document.body, mask_div);
        dc_addevent(window, 'resize', resize_mask);
        resize_mask(null);
      }
      else
      {
        dc_dragging(header_div, {content:window_div});
        dc_style(header_div, {cursor:'move'});
        dc_del(mask_div);
      }

      dc_style(window_div, { minWidth : width + 8 });

      if (height > 0)
      {
        dc_style(window_div, {height:(height+33)});
        dc_style(content_div, {height:height});
      }
      else
      {
        dc_style(window_div, {height:''});
        dc_style(content_div, {height:''});
      }

      dc_clear(title_div);
      dc_add(title_div, dc_text(title));

      if (typeof(content) == 'string')
      {
        content_div.innerHTML = content;
      }
      else
      {
        dc_clear(content_div);
        dc_add(content_div, content);
      }

      dc_center(window_div);
    }
  }

  this.Show = function()
  {
    if (window_div)
    {
      var z = dc_maxz();
      dc_style(window_div, {display:'block', zIndex:(z+2)});
      if (modal) dc_style(mask_div, {display:'block', zIndex:(z+1)});
      dc_add(document.body, window_div);
    }
  }

  this.Hide = function()
  {
    if (window_div)
    {
      dc_style(window_div, {display:'none'});
      dc_style(mask_div, {display:'none'});
    }
  }

  this.Close = function(e)
  {
    if (window_div)
    {
      dc_del(window_div);
      dc_del(mask_div);

      title = null;
      width = null;
      height = null;
      content = null;

      window_div = null;
      header_div = null;
      title_div = null;
      content_div = null;
      mask_div = null;

      this.content_div = null;
    }
  }

  //--- init code

  dc_add
  (
    window_div,
    dc_add
    (
      header_div,
      title_div,
      dc_input_button('', ' X ', {click:this.Close, style:'float:right; height:25px;'})
    ),
    content_div
  );

  this.Show();
  this.Update(args);
}

function dc_window(args)
{
  return new DCWIN(args);
}
