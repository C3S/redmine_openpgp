# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

get 'pgp', :to => 'pgpkeys#index'
post 'pgp/create', :to => 'pgpkeys#create'
post 'pgp/delete', :to => 'pgpkeys#delete'
post 'pgp/generate', :to => 'pgpkeys#generate'