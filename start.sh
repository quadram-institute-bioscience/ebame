#docker run -i -t --rm -u 1000:1000 -p 4000:4000 -v `pwd`:/opt/app -v `pwd`/.bundler/:/opt/bundler -e BUNDLE_PATH=~/opt/bundler -w /opt/app ruby:2.7 bash -c "bundle install && bundle exec jekyll serve --watch -H 0.0.0.0"

#mamba create -y -n jekyll -c conda-forge rb-jekyll c-compiler compilers cxx-compiler
#conda activate jekyll
#gem install bundler
#bundle update
#gem install rubygems-update
#update_rubygems
#gem install rubygems-update -v 3.4.22
#update_rubygems
bundle install && bundle exec jekyll serve --watch -H 0.0.0.0
