function addHierarchy(obj) {
  var chain = new Array('Browse Files');
  var path = obj.location;
  var extension = path.substring(path.lastIndexOf('.')+1);
  var filter=0;

  //determine path of file
  if (path.indexOf('music')>0 && extension in {'mp3':0,'wav':0,'wma':0,'ogg':0,'m4a':0} ) {
    path=path.substring(path.indexOf('music')+6, path.lastIndexOf('/'));
    chain.push('Music');
  } else if (path.indexOf('pictures')>0 )  {
    path=path.substring(path.indexOf('pictures')+14, path.lastIndexOf('/'));
    chain.push('Pictures');
  } else if (path.indexOf('music')>0 && extension in {'avi':0,'mpg':0,'mkv':0, 'mp4':0} ) {
    path=path.substring(path.indexOf('music')+6, path.lastIndexOf('/'));
    chain.push('Videos');
  } else {
    filter=1; //don't include file
  }

  //set display name
  if (obj.meta[M_ARTIST]) {
    obj.title = obj.meta[M_ARTIST] + ' - ' + obj.title;
  }

  //insert item into it's own folder as well as virtual "all files" folder
  if (filter != 1) {
    chain = chain.concat(path.split('/'));
    addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC);
    while (chain.length>3) {
      chain.push('--All Files--');
      addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC);
      chain.pop();
      chain.pop();
    }
  }
}
