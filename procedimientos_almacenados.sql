-- 1. Crear una nueva cuenta bancaria.
-- Crea una nueva cuenta bancaria para un cliente, asignando un número de cuenta único y estableciendo un saldo inicial.

CREATE OR REPLACE PROCEDURE CrearCuentaBancaria(
    IN p_cliente_id INTEGER,
    IN p_numero_cuenta VARCHAR(20),
    IN p_saldo DECIMAL(15, 2),
    IN p_estado VARCHAR(10) DEFAULT 'activa'
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO Cuentas_Bancarias (cliente_id, numero_cuenta, saldo, estado)
    VALUES (p_cliente_id, p_numero_cuenta, p_saldo, p_estado);
END;
$$;

CALL CrearCuentaBancaria(1, '12345678902', 1000.00);


-- 2. Actualizar la información del cliente
-- Actualiza la información personal de un cliente, como dirección, teléfono y correo electrónico, basado en el ID del cliente.

CREATE OR REPLACE PROCEDURE ActualizarCliente(
    IN p_cliente_id INTEGER,
    IN p_direccion VARCHAR(255),
    IN p_telefono VARCHAR(20),
    IN p_correo_electronico VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE Clientes
    SET direccion = p_direccion,
        telefono = p_telefono,
        correo_electronico = p_correo_electronico
    WHERE cliente_id = p_cliente_id;
END;
$$;

CALL ActualizarCliente(1, 'aldena nuera deli', '98565767764', 'nuevo.email@example.com');


-- 3. Eliminar una cuenta bancaria
-- Elimina una cuenta bancaria específica del sistema, incluyendo la eliminación de todas las transacciones asociadas.

CREATE OR REPLACE PROCEDURE EliminarCuentaBancaria(
    IN p_numero_cuenta VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta_id INTEGER;
BEGIN
    SELECT cuenta_id INTO v_cuenta_id
    FROM Cuentas_Bancarias
    WHERE numero_cuenta = p_numero_cuenta;

    IF v_cuenta_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta bancaria con el número % no existe.', p_numero_cuenta;
    END IF;

    DELETE FROM Transacciones
    WHERE cuenta_id = v_cuenta_id;

    DELETE FROM Cuentas_Bancarias
    WHERE cuenta_id = v_cuenta_id;
END;
$$;

CALL EliminarCuentaBancaria('1234567890');


-- 4.Transferir fondos entre cuentas
-- Realiza una transferencia de fondos desde una cuenta a otra, asegurando que ambas cuentas se actualicen correctamente y se registre la transacción.

CREATE OR REPLACE PROCEDURE TransferirFondos(
    IN p_cuenta_origen VARCHAR(20),
    IN p_cuenta_destino VARCHAR(20),
    IN p_monto NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta_origen_id INTEGER;
    v_cuenta_destino_id INTEGER;
    v_saldo_origen NUMERIC;
BEGIN
    -- Obtener el ID de la cuenta de origen
    SELECT cuenta_id, saldo INTO v_cuenta_origen_id, v_saldo_origen
    FROM Cuentas_Bancarias
    WHERE numero_cuenta = p_cuenta_origen;

    -- Verificar si la cuenta de origen existe
    IF v_cuenta_origen_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta bancaria de origen con el número % no existe.', p_cuenta_origen;
    END IF;

    -- Obtener el ID de la cuenta de destino
    SELECT cuenta_id INTO v_cuenta_destino_id
    FROM Cuentas_Bancarias
    WHERE numero_cuenta = p_cuenta_destino;

    -- Verificar si la cuenta de destino existe
    IF v_cuenta_destino_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta bancaria de destino con el número % no existe.', p_cuenta_destino;
    END IF;

    -- Verificar si la cuenta de origen tiene fondos suficientes
    IF v_saldo_origen < p_monto THEN
        RAISE EXCEPTION 'Fondos insuficientes en la cuenta de origen.';
    END IF;

    -- Actualizar el saldo de la cuenta de origen
    UPDATE Cuentas_Bancarias
    SET saldo = saldo - p_monto
    WHERE cuenta_id = v_cuenta_origen_id;

    -- Actualizar el saldo de la cuenta de destino
    UPDATE Cuentas_Bancarias
    SET saldo = saldo + p_monto
    WHERE cuenta_id = v_cuenta_destino_id;

    -- Registrar la transacción de débito en la cuenta de origen
    INSERT INTO Transacciones (cuenta_id, tipo, monto, descripcion)
    VALUES (v_cuenta_origen_id, 'DEBITO', p_monto, 'Transferencia a cuenta ' || p_cuenta_destino);

    -- Registrar la transacción de crédito en la cuenta de destino
    INSERT INTO Transacciones (cuenta_id, tipo, monto, descripcion)
    VALUES (v_cuenta_destino_id, 'CREDITO', p_monto, 'Transferencia desde cuenta ' || p_cuenta_origen);
END;
$$;

CALL TransferirFondos('1234567890', '0987654321', 100.00);


-- 5. Agregar una nueva transacción
-- Registra una nueva transacción (depósito, retiro) en el sistema, actualizando el saldo de la cuenta asociada.

CREATE OR REPLACE PROCEDURE RegistrarTransaccion(
    IN p_numero_cuenta VARCHAR(20),
    IN p_tipo_transaccion VARCHAR(10),
    IN p_monto NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta_id INTEGER;
    v_saldo_actual NUMERIC;
BEGIN
    -- Obtener el ID y el saldo actual de la cuenta
    SELECT cuenta_id, saldo INTO v_cuenta_id, v_saldo_actual
    FROM Cuentas_Bancarias
    WHERE numero_cuenta = p_numero_cuenta;

    -- Verificar si la cuenta existe
    IF v_cuenta_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta bancaria con el número % no existe.', p_numero_cuenta;
    END IF;

    -- Verificar si el tipo de transacción es válido
    IF p_tipo_transaccion NOT IN ('DEPOSITO', 'RETIRO') THEN
        RAISE EXCEPTION 'Tipo de transacción inválido. Debe ser DEPOSITO o RETIRO.';
    END IF;

    -- Verificar si la cuenta tiene fondos suficientes en caso de un retiro
    IF p_tipo_transaccion = 'RETIRO' AND v_saldo_actual < p_monto THEN
        RAISE EXCEPTION 'Fondos insuficientes en la cuenta para realizar el retiro.';
    END IF;

    -- Actualizar el saldo de la cuenta
    IF p_tipo_transaccion = 'DEPOSITO' THEN
        UPDATE Cuentas_Bancarias
        SET saldo = saldo + p_monto
        WHERE cuenta_id = v_cuenta_id;
    ELSE
        UPDATE Cuentas_Bancarias
        SET saldo = saldo - p_monto
        WHERE cuenta_id = v_cuenta_id;
    END IF;

    -- Registrar la transacción
    INSERT INTO Transacciones (cuenta_id, tipo, monto, descripcion)
    VALUES (v_cuenta_id, p_tipo_transaccion, p_monto, p_tipo_transaccion || ' de ' || p_monto || ' a la cuenta ' || p_numero_cuenta);
END;
$$;

CALL RegistrarTransaccion('1234567890', 'DEPOSITO', 5000);


-- 6. Calcular el saldo total de todas las cuentas de un cliente
-- Calcula el saldo total combinado de todas las cuentas bancarias pertenecientes a un cliente específico.

CREATE OR REPLACE PROCEDURE calcular_saldo_total_cliente(
    p_cliente_id INTEGER,
    OUT p_saldo_total NUMERIC(12, 2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT SUM(saldo) INTO p_saldo_total
    FROM cuentas_bancarias
    WHERE cliente_id = p_cliente_id;
END;
$$;

call calcular_saldo_total_cliente(2, 0);


-- 7. Generar un reporte de transacciones para un rango de fechas
-- Genera un reporte detallado de todas las transacciones realizadas en un rango de fechas específico.

CREATE OR REPLACE FUNCTION generarReporteTransacciones(
    p_fecha_inicio DATE,
    p_fecha_fin DATE
)
RETURNS TABLE (
    transaccion_id INTEGER,
    cuenta_id INTEGER,
    tipo_transaccion VARCHAR(10),
    monto NUMERIC,
    descripcion TEXT,
    fecha DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.transaccion_id,
        t.cuenta_id,
        t.tipo_transaccion,
        t.monto,
        t.descripcion,
        t.fecha_apertura
    FROM 
        transacciones t
    WHERE 
        t.fecha BETWEEN p_fecha_inicio AND p_fecha_fin
    ORDER BY 
        t.fecha;
END;
$$;

SELECT * FROM generarReporteTransacciones('2023-01-01', '2023-12-31');

