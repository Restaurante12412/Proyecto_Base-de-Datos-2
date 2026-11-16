-- MypeInventario - ORACLE
-- 2. Tablas
-- Ejecutar DESPUES de "1. Base_datos.sql" y conectado como el esquema
-- MYPE_INVENTARIO (las tablas se crean en el esquema del usuario conectado):
--   sqlplus MYPE_INVENTARIO@localhost:1521/FREEPDB1 @"2. Tablas.sql"

--CODIGO 2: Creacion de las 20 tablas de Oracle (sin FK)

CREATE TABLE Comerciante (
    id_comerciante   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombres          VARCHAR2(100) NOT NULL,
    apellidos        VARCHAR2(100) NOT NULL,
    documento        VARCHAR2(20)  NOT NULL,
    telefono         VARCHAR2(20),
    email            VARCHAR2(150),
    fecha_registro   DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT uq_comerciante_documento UNIQUE (documento),
    CONSTRAINT uq_comerciante_email UNIQUE (email)
);

CREATE TABLE Negocio (
    id_negocio       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_comerciante   NUMBER NOT NULL,
    nombre           VARCHAR2(150) NOT NULL,
    ruc              VARCHAR2(11),
    direccion        VARCHAR2(200),
    telefono         VARCHAR2(20),
    email            VARCHAR2(150),
    fecha_registro   DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT uq_negocio_ruc UNIQUE (ruc),
    CONSTRAINT ck_negocio_ruc CHECK (ruc IS NULL OR LENGTH(ruc) = 11)
);

CREATE TABLE Sucursal (
    id_sucursal   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_negocio    NUMBER NOT NULL,
    nombre        VARCHAR2(100) NOT NULL,
    direccion     VARCHAR2(200) NOT NULL,
    telefono      VARCHAR2(20),
    estado        VARCHAR2(20) DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT ck_sucursal_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE Empleado (
    id_empleado   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal   NUMBER NOT NULL,
    nombres       VARCHAR2(100) NOT NULL,
    apellidos     VARCHAR2(100) NOT NULL,
    documento     VARCHAR2(20)  NOT NULL,
    cargo         VARCHAR2(80),
    telefono      VARCHAR2(20),
    email         VARCHAR2(150),
    estado        VARCHAR2(20) DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT uq_empleado_documento UNIQUE (documento),
    CONSTRAINT uq_empleado_email UNIQUE (email),
    CONSTRAINT ck_empleado_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE Proveedor (
    id_proveedor   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_negocio     NUMBER NOT NULL,
    razon_social   VARCHAR2(150) NOT NULL,
    ruc            VARCHAR2(11),
    telefono       VARCHAR2(20),
    email          VARCHAR2(150),
    direccion      VARCHAR2(200),
    CONSTRAINT uq_proveedor_ruc UNIQUE (ruc),
    CONSTRAINT ck_proveedor_ruc CHECK (ruc IS NULL OR LENGTH(ruc) = 11)
);

CREATE TABLE CategoriaProducto (
    id_categoria   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_negocio     NUMBER NOT NULL,
    nombre         VARCHAR2(100) NOT NULL,
    descripcion    VARCHAR2(250)
);

CREATE TABLE Producto (
    id_producto    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria   NUMBER NOT NULL,
    nombre         VARCHAR2(150) NOT NULL,
    descripcion    VARCHAR2(500),
    marca          VARCHAR2(100),
    estado         VARCHAR2(20) DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT ck_producto_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE VarianteSKU (
    id_sku          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto     NUMBER NOT NULL,
    codigo_sku      VARCHAR2(50) NOT NULL,
    talla           VARCHAR2(30),
    color           VARCHAR2(50),
    precio_venta    NUMBER(10,2) NOT NULL,
    precio_compra   NUMBER(10,2),
    estado          VARCHAR2(20) DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT uq_sku_codigo UNIQUE (codigo_sku),
    CONSTRAINT ck_sku_precio_venta CHECK (precio_venta >= 0),
    CONSTRAINT ck_sku_precio_compra CHECK (precio_compra IS NULL OR precio_compra >= 0),
    CONSTRAINT ck_sku_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE Compra (
    id_compra      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_proveedor   NUMBER NOT NULL,
    id_sucursal    NUMBER NOT NULL,
    fecha_compra   DATE DEFAULT SYSDATE NOT NULL,
    numero_doc     VARCHAR2(30),
    subtotal       NUMBER(12,2) NOT NULL,
    impuesto       NUMBER(12,2) DEFAULT 0 NOT NULL,
    total          NUMBER(12,2) NOT NULL,
    estado         VARCHAR2(20) DEFAULT 'REGISTRADA' NOT NULL,
    CONSTRAINT ck_compra_subtotal CHECK (subtotal >= 0),
    CONSTRAINT ck_compra_impuesto CHECK (impuesto >= 0),
    CONSTRAINT ck_compra_total CHECK (total >= 0),
    CONSTRAINT ck_compra_estado CHECK (estado IN ('REGISTRADA','ANULADA'))
);

CREATE TABLE DetalleCompra (
    id_detalle_compra   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_compra           NUMBER NOT NULL,
    id_sku              NUMBER NOT NULL,
    cantidad            NUMBER(10,2) NOT NULL,
    precio_unitario     NUMBER(10,2) NOT NULL,
    subtotal            NUMBER(12,2) NOT NULL,
    CONSTRAINT ck_detcompra_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detcompra_preciounit CHECK (precio_unitario >= 0),
    CONSTRAINT ck_detcompra_subtotal CHECK (subtotal >= 0)
);

CREATE TABLE Cliente (
    id_cliente    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_negocio    NUMBER NOT NULL,
    nombres       VARCHAR2(100) NOT NULL,
    apellidos     VARCHAR2(100),
    documento     VARCHAR2(20),
    telefono      VARCHAR2(20),
    email         VARCHAR2(150)
);

CREATE TABLE Venta (
    id_venta      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente    NUMBER,
    id_empleado   NUMBER NOT NULL,
    id_sucursal   NUMBER NOT NULL,
    fecha_venta   DATE DEFAULT SYSDATE NOT NULL,
    subtotal      NUMBER(12,2) NOT NULL,
    descuento     NUMBER(12,2) DEFAULT 0 NOT NULL,
    impuesto      NUMBER(12,2) DEFAULT 0 NOT NULL,
    total         NUMBER(12,2) NOT NULL,
    estado        VARCHAR2(20) DEFAULT 'REGISTRADA' NOT NULL,
    CONSTRAINT ck_venta_subtotal CHECK (subtotal >= 0),
    CONSTRAINT ck_venta_descuento CHECK (descuento >= 0),
    CONSTRAINT ck_venta_impuesto CHECK (impuesto >= 0),
    CONSTRAINT ck_venta_total CHECK (total >= 0),
    CONSTRAINT ck_venta_estado CHECK (estado IN ('REGISTRADA','ANULADA'))
);

CREATE TABLE DetalleVenta (
    id_detalle_venta   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_venta           NUMBER NOT NULL,
    id_sku             NUMBER NOT NULL,
    cantidad           NUMBER(10,2) NOT NULL,
    precio_unitario    NUMBER(10,2) NOT NULL,
    descuento          NUMBER(10,2) DEFAULT 0 NOT NULL,
    subtotal           NUMBER(12,2) NOT NULL,
    CONSTRAINT ck_detventa_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detventa_preciounit CHECK (precio_unitario >= 0),
    CONSTRAINT ck_detventa_descuento CHECK (descuento >= 0),
    CONSTRAINT ck_detventa_subtotal CHECK (subtotal >= 0)
);

CREATE TABLE MetodoPago (
    id_metodo_pago   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_venta         NUMBER NOT NULL,
    tipo_pago        VARCHAR2(30) NOT NULL,
    monto            NUMBER(12,2) NOT NULL,
    referencia       VARCHAR2(100),
    CONSTRAINT ck_metpago_tipo CHECK (tipo_pago IN ('EFECTIVO','TARJETA','YAPE','PLIN','TRANSFERENCIA','OTRO')),
    CONSTRAINT ck_metpago_monto CHECK (monto >= 0)
);

CREATE TABLE DireccionCliente (
    id_direccion    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente      NUMBER,
    direccion       VARCHAR2(200) NOT NULL,
    referencia      VARCHAR2(250),
    distrito        VARCHAR2(100),
    provincia       VARCHAR2(100),
    departamento    VARCHAR2(100),
    codigo_postal   VARCHAR2(10),
    principal       NUMBER(1) DEFAULT 0 NOT NULL,
    CONSTRAINT ck_direccioncliente_principal CHECK (principal IN (0,1))
);

CREATE TABLE Pedido (
    id_pedido     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente    NUMBER NOT NULL,
    id_sucursal   NUMBER,
    fecha_pedido  DATE DEFAULT SYSDATE NOT NULL,
    estado        VARCHAR2(20) DEFAULT 'PENDIENTE' NOT NULL,
    subtotal      NUMBER(12,2) NOT NULL,
    descuento     NUMBER(12,2) DEFAULT 0 NOT NULL,
    impuesto      NUMBER(12,2) DEFAULT 0 NOT NULL,
    total         NUMBER(12,2) NOT NULL,
    CONSTRAINT ck_pedido_subtotal CHECK (subtotal >= 0),
    CONSTRAINT ck_pedido_descuento CHECK (descuento >= 0),
    CONSTRAINT ck_pedido_impuesto CHECK (impuesto >= 0),
    CONSTRAINT ck_pedido_total CHECK (total >= 0),
    CONSTRAINT ck_pedido_estado CHECK (estado IN ('PENDIENTE','CONFIRMADO','ANULADO','ENTREGADO'))
);

CREATE TABLE DetallePedido (
    id_detalle_pedido  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido          NUMBER NOT NULL,
    id_sku             NUMBER NOT NULL,
    cantidad           NUMBER(10,2) NOT NULL,
    precio_unitario    NUMBER(10,2) NOT NULL,
    descuento          NUMBER(10,2) DEFAULT 0 NOT NULL,
    subtotal           NUMBER(12,2) NOT NULL,
    CONSTRAINT ck_detpedido_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detpedido_preciounit CHECK (precio_unitario >= 0),
    CONSTRAINT ck_detpedido_descuento CHECK (descuento >= 0),
    CONSTRAINT ck_detpedido_subtotal CHECK (subtotal >= 0)
);

CREATE TABLE CanalVenta (
    id_canal      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_negocio    NUMBER NOT NULL,
    nombre        VARCHAR2(50) NOT NULL,
    descripcion   VARCHAR2(200),
    estado        VARCHAR2(20) DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT ck_canalventa_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE VentaCanal (
    id_venta_canal      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_venta            NUMBER NOT NULL,
    id_canal            NUMBER NOT NULL,
    referencia_externa  VARCHAR2(100),
    fecha_registro      DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE PromocionComercial (
    id_promocion   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_negocio     NUMBER NOT NULL,
    nombre         VARCHAR2(150) NOT NULL,
    descripcion    VARCHAR2(250),
    tipo           VARCHAR2(30) NOT NULL,
    valor          NUMBER(10,2) NOT NULL,
    fecha_inicio   DATE NOT NULL,
    fecha_fin      DATE NOT NULL,
    estado         VARCHAR2(20) DEFAULT 'ACTIVA' NOT NULL,
    CONSTRAINT ck_promocion_valor CHECK (valor >= 0),
    CONSTRAINT ck_promocion_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT ck_promocion_estado CHECK (estado IN ('ACTIVA','INACTIVA','VENCIDA'))
);

-- CODIGO 3: FK internas de las 20 tablas de Oracle

ALTER TABLE Negocio
ADD CONSTRAINT fk_negocio_comerciante
FOREIGN KEY (id_comerciante)
REFERENCES Comerciante(id_comerciante);

ALTER TABLE Sucursal
ADD CONSTRAINT fk_sucursal_negocio
FOREIGN KEY (id_negocio)
REFERENCES Negocio(id_negocio);

ALTER TABLE Empleado
ADD CONSTRAINT fk_empleado_sucursal
FOREIGN KEY (id_sucursal)
REFERENCES Sucursal(id_sucursal);

ALTER TABLE Proveedor
ADD CONSTRAINT fk_proveedor_negocio
FOREIGN KEY (id_negocio)
REFERENCES Negocio(id_negocio);

ALTER TABLE CategoriaProducto
ADD CONSTRAINT fk_categoria_negocio
FOREIGN KEY (id_negocio)
REFERENCES Negocio(id_negocio);

ALTER TABLE Producto
ADD CONSTRAINT fk_producto_categoria
FOREIGN KEY (id_categoria)
REFERENCES CategoriaProducto(id_categoria);

ALTER TABLE VarianteSKU
ADD CONSTRAINT fk_variantesku_producto
FOREIGN KEY (id_producto)
REFERENCES Producto(id_producto);

ALTER TABLE Compra
ADD CONSTRAINT fk_compra_proveedor
FOREIGN KEY (id_proveedor)
REFERENCES Proveedor(id_proveedor);

ALTER TABLE Compra
ADD CONSTRAINT fk_compra_sucursal
FOREIGN KEY (id_sucursal)
REFERENCES Sucursal(id_sucursal);

ALTER TABLE DetalleCompra
ADD CONSTRAINT fk_detcompra_compra
FOREIGN KEY (id_compra)
REFERENCES Compra(id_compra);

ALTER TABLE DetalleCompra
ADD CONSTRAINT fk_detcompra_sku
FOREIGN KEY (id_sku)
REFERENCES VarianteSKU(id_sku);

ALTER TABLE Cliente
ADD CONSTRAINT fk_cliente_negocio
FOREIGN KEY (id_negocio)
REFERENCES Negocio(id_negocio);

ALTER TABLE Venta
ADD CONSTRAINT fk_venta_cliente
FOREIGN KEY (id_cliente)
REFERENCES Cliente(id_cliente);

ALTER TABLE Venta
ADD CONSTRAINT fk_venta_empleado
FOREIGN KEY (id_empleado)
REFERENCES Empleado(id_empleado);

ALTER TABLE Venta
ADD CONSTRAINT fk_venta_sucursal
FOREIGN KEY (id_sucursal)
REFERENCES Sucursal(id_sucursal);

ALTER TABLE DetalleVenta
ADD CONSTRAINT fk_detventa_venta
FOREIGN KEY (id_venta)
REFERENCES Venta(id_venta);

ALTER TABLE DetalleVenta
ADD CONSTRAINT fk_detventa_sku
FOREIGN KEY (id_sku)
REFERENCES VarianteSKU(id_sku);

ALTER TABLE MetodoPago
ADD CONSTRAINT fk_metodopago_venta
FOREIGN KEY (id_venta)
REFERENCES Venta(id_venta);

ALTER TABLE DireccionCliente
ADD CONSTRAINT fk_direccioncliente_cliente
FOREIGN KEY (id_cliente)
REFERENCES Cliente(id_cliente);

ALTER TABLE Pedido
ADD CONSTRAINT fk_pedido_cliente
FOREIGN KEY (id_cliente)
REFERENCES Cliente(id_cliente);

ALTER TABLE Pedido
ADD CONSTRAINT fk_pedido_sucursal
FOREIGN KEY (id_sucursal)
REFERENCES Sucursal(id_sucursal);

ALTER TABLE DetallePedido
ADD CONSTRAINT fk_detpedido_pedido
FOREIGN KEY (id_pedido)
REFERENCES Pedido(id_pedido);

ALTER TABLE DetallePedido
ADD CONSTRAINT fk_detpedido_sku
FOREIGN KEY (id_sku)
REFERENCES VarianteSKU(id_sku);

ALTER TABLE CanalVenta
ADD CONSTRAINT fk_canalventa_negocio
FOREIGN KEY (id_negocio)
REFERENCES Negocio(id_negocio);

ALTER TABLE VentaCanal
ADD CONSTRAINT fk_ventacanal_venta
FOREIGN KEY (id_venta)
REFERENCES Venta(id_venta);

ALTER TABLE VentaCanal
ADD CONSTRAINT fk_ventacanal_canal
FOREIGN KEY (id_canal)
REFERENCES CanalVenta(id_canal);

ALTER TABLE PromocionComercial
ADD CONSTRAINT fk_promocion_negocio
FOREIGN KEY (id_negocio)
REFERENCES Negocio(id_negocio);
