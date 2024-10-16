---
layout: page
---

<details>
  <summary>What is this script doing?</summary>
  
The script will:

* Check you are on an EBAME VM
   
* Install some packages with apt, including `visidata` is a tool to visualise tabular data (tsv, csv).
   
* Install a configuration profile for GNU Screen
   
* Make a `$VIROME` variable to quickly find our data

</details>


:warning: if the connection to a remote machine drops, the running programs will be terminated. 
See a small tutorial on [GNU screen :link:](https://github.com/telatin/learn_bash/wiki/Using-%22screen%22) on how to manage this problem.