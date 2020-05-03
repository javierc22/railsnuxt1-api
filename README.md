# README

Crear Proyecto 
~~~console
$ rails new railsnuxt1-api -d postgresql --api -T
~~~

Crear controladores 'sessions' para Login
~~~console
rails g controller Api::V1::User::Sessions sign_in sign_out me
~~~

## Explicación GK Error

Agregar la clase **GK Error** en **initializers** ('to_prepare' devuelve una respuesta que se ejecutará antes de cada solicitud en modo desarrollo o antes de la primera solicitud en producción)
~~~ruby
# config/initializers/gk_error.rb

Rails.configuration.to_prepare do
  class GKError < StandardError
  end

  class GKAuthenticationError < StandardError
  end
end
~~~

Configurar **AppController** para los errores 400 y 401 al realizar una solicitud a la API
~~~ruby
# app/controllers/api/app_controller.rb

class Api::AppController < ApplicationController
  rescue_from GKError, with: :handle_400
  rescue_from GKAuthenticationError, with: :handle_401

  def handle_400(exception)
    render json: { success: false, error: exception.message }, status: :bad_request and return
  end

  def handle_401(exception)
    render json: { success: false, error: exception.message }, status: :unauthorized and return
  end
end
~~~

En **SessionsController** generar una respuesta para error 400
~~~rb
# app/controllers/api/v1/user/sessions_controller.rb

class Api::V1::User::SessionsController < Api::V1::User::AppController
  def sign_in
    raise GKError.new("hello world con error 400: Bad request")
    #raise GKAuthenticationError.new("hello world con error 401")
  end

  def sign_out
  end

  def me
  end
end
~~~

Realizando prueba y obteniendo respuesta para error **400**
<img src="./readme_img/img01.png" height="400">

En **SessionsController** generar una respuesta para error 401
~~~rb
# app/controllers/api/v1/user/sessions_controller.rb

class Api::V1::User::SessionsController < Api::V1::User::AppController
  def sign_in
    #raise GKError.new("hello world con error 400: Bad request")
    raise GKAuthenticationError.new("hello world con error 401: Unathorized")
  end

  def sign_out
  end

  def me
  end
end
~~~

Realizando prueba y obteniendo respuesta para error **401**
<img src="./readme_img/img02.png" height="450">

## Generar Token

Hasta el commit `7fa884b` podemos generar un Token con el método `jwt`
~~~console
2.6.5 :001 > User.new
 => #<User id: nil, first_name: nil, last_name: nil, created_at: nil, updated_at: nil, email: "">

2.6.5 :002 > User.create(email:'user01@email.com', password:'hola123')
   (0.2ms)  BEGIN
  User Exists? (0.5ms)  SELECT 1 AS one FROM "users" WHERE "users"."email" = $1 LIMIT $2  [["email", "user01@email.com"], ["LIMIT", 1]]
  User Create (0.4ms)  INSERT INTO "users" ("created_at", "updated_at", "email", "encrypted_password") VALUES ($1, $2, $3, $4) RETURNING "id"  [["created_at", "2020-05-03 19:42:49.351774"], ["updated_at", "2020-05-03 19:42:49.351774"], ["email", "user01@email.com"], ["encrypted_password", "$2a$11$rCxdAj2lzAvn9Z9miQ.MK.YRpDHZIV0mupQIhyR33YQfVBVleCjnq"]]
   (1.9ms)  COMMIT
 => #<User id: 1, first_name: nil, last_name: nil, created_at: "2020-05-03 19:42:49", updated_at: "2020-05-03 19:42:49", email: "user01@email.com"> 

2.6.5 :004 > User.first.jwt
  User Load (1.0ms)  SELECT "users".* FROM "users" ORDER BY "users"."id" ASC LIMIT $1  [["LIMIT", 1]]
 => "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6MSwiZXhwIjoxNTg4NjIxNDE3fQ.BQqMvmui-wUCyccaJnL1tw-N1JaJfuZRQrc2zcG1mXY" 
~~~

### Generando UUID para usarlo con JWT

~~~ruby
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  before_create :generate_auth_token

  # Genera un UUID
  def generate_auth_token
    self.auth_token = SecureRandom.uuid
  end

  def jwt(exp = 15.days.from_now)
    JWT.encode({ auth_token: self.auth_token, exp: exp.to_i }, Rails.application.credentials.secret_key_base, "HS256")
  end

  def as_json_with_jwt
    json = self.as_json
    json[:auth_jwt] = self.jwt
    json
  end
end
~~~

~~~console
2.6.5 :001 > user = User.first
  User Load (0.4ms)  SELECT "users".* FROM "users" ORDER BY "users"."id" ASC LIMIT $1  [["LIMIT", 1]]
 => #<User id: 1, first_name: nil, last_name: nil, created_at: "2020-05-03 19:42:49", updated_at: "2020-05-03 19:42:49", email: "user01@email.com", auth_token: nil> 

2.6.5 :002 > user.generate_auth_token
 => "166637f5-32bd-4dc4-948b-1c7c52f8a105" 

2.6.5 :003 > user.save
   (0.2ms)  BEGIN
  User Update (0.4ms)  UPDATE "users" SET "updated_at" = $1, "auth_token" = $2 WHERE "users"."id" = $3  [["updated_at", "2020-05-03 20:13:46.569756"], ["auth_token", "166637f5-32bd-4dc4-948b-1c7c52f8a105"], ["id", 1]]
   (1.7ms)  COMMIT
 => true 

2.6.5 :004 > user.jwt
 => "eyJhbGciOiJIUzI1NiJ9.eyJhdXRoX3Rva2VuIjoiMTY2NjM3ZjUtMzJiZC00ZGM0LTk0OGItMWM3YzUyZjhhMTA1IiwiZXhwIjoxNTg5ODMyODM1fQ.brTmdaPuwe_9RJwZlhoh6eD0EsKMN-rVPbGiJi9bVls" 

2.6.5 :005 > u = User.find_by_auth_token('166637f5-32bd-4dc4-948b-1c7c52f8a105')
  User Load (0.3ms)  SELECT "users".* FROM "users" WHERE "users"."auth_token" = $1 LIMIT $2  [["auth_token", "166637f5-32bd-4dc4-948b-1c7c52f8a105"], ["LIMIT", 1]]
 => #<User id: 1, first_name: nil, last_name: nil, created_at: "2020-05-03 19:42:49", updated_at: "2020-05-03 20:13:46", email: "user01@email.com", auth_token: "166637f5-32bd-4dc4-948b-1c7c52f8a105"> 

2.6.5 :006 > u.as_json_with_jwt
 => {"id"=>1, "first_name"=>nil, "last_name"=>nil, "created_at"=>"2020-05-03T19:42:49.351Z", "updated_at"=>"2020-05-03T20:13:46.569Z", "email"=>"user01@email.com", "auth_token"=>"166637f5-32bd-4dc4-948b-1c7c52f8a105", :auth_jwt=>"eyJhbGciOiJIUzI1NiJ9.eyJhdXRoX3Rva2VuIjoiMTY2NjM3ZjUtMzJiZC00ZGM0LTk0OGItMWM3YzUyZjhhMTA1IiwiZXhwIjoxNTg5ODMzMDM5fQ.6NKn4ujSWmS-x_6K7wZWG_qQ8i4Qwnf7H0gHhaUhyMI"} 
~~~

## Realizando pruebas con Postman

Haciendo Login y obteniendo Token

<img src="./readme_img/img03.png" height="450">

<img src="./readme_img/img04.png" height="450">

Mostrando Usuario según el Token

<img src="./readme_img/img05.png" height="450">

<img src="./readme_img/img06.png" height="450">

Cerrar sesión

<img src="./readme_img/img07.png" height="450">

## Crear Blog

Crear modelo
~~~bash
rails g model blog title body:text user:references
~~~

Crear controladores
~~~console
rails g controller Api::V1::User::Blogs index show create update destroy
~~~

Para las pruebas. Fijarse de tener los **headers** con un token válido

<img src="./readme_img/img08.png" height="100">

Crear Blog

<img src="./readme_img/img09.png" height="450">

Obtener Blog

<img src="./readme_img/img10.png" height="450">

Actualizar
<img src="./readme_img/img11.png" height="450">

Eliminar
<img src="./readme_img/img12.png" height="450">
